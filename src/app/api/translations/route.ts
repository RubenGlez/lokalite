import { and, eq, not, sql } from 'drizzle-orm'
import { NextRequest, NextResponse } from 'next/server'
import { batchTranslate } from '~/lib/translation-agent'
import { db } from '~/server/db'
import { languages, translationKeys, translations } from '~/server/db/schema'
import { z } from 'zod'

const translateBodySchema = z.object({
  pageId: z.string(),
  projectId: z.string(),
  sourceLanguageCode: z.string(),
  translations: z.record(z.string())
})

const getTranslationsSchema = z.object({
  pageId: z.string(),
  projectId: z.string()
})

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const pageId = searchParams.get('pageId')
    const projectId = searchParams.get('projectId')

    const params = getTranslationsSchema.parse({ pageId, projectId })

    const translationsList = await db
      .select()
      .from(translations)
      .where(eq(translations.pageId, params.pageId))

    const translationKeysList = await db
      .select()
      .from(translationKeys)
      .where(eq(translationKeys.pageId, params.pageId))

    const languageCodes = await db
      .select()
      .from(languages)
      .where(eq(languages.projectId, params.projectId))

    const translationsByLanguage = languageCodes.reduce((acc, language) => {
      return {
        ...acc,
        [language.code]: translationKeysList.reduce((acc, key) => {
          const translation = translationsList.find(
            (translation) =>
              translation.translationKeyId === key.id &&
              translation.languageCode === language.code
          )

          return { ...acc, [key.key]: translation?.value }
        }, {})
      }
    }, {})

    return new Response(JSON.stringify(translationsByLanguage), { status: 200 })
  } catch (error) {
    console.error('Error in GET /translations:', error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 400
    })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = translateBodySchema.parse(await request.json())

    const {
      pageId,
      projectId,
      sourceLanguageCode,
      translations: itemsToTranslate // {key: text}
    } = body

    const languagesToTranslate = await db
      .select()
      .from(languages)
      .where(
        and(
          eq(languages.projectId, projectId),
          not(eq(languages.code, sourceLanguageCode))
        )
      )

    const allKeys = Object.keys(itemsToTranslate).map((key) => ({
      key,
      pageId,
      updatedAt: new Date()
    }))

    const newKeys = await db
      .insert(translationKeys)
      .values(allKeys)
      .onConflictDoUpdate({
        target: [translationKeys.pageId, translationKeys.key],
        set: {
          key: sql`excluded.key`,
          description: sql`excluded.description`,
          updatedAt: new Date()
        }
      })
      .returning()

    const items = Object.entries(itemsToTranslate).flatMap(([key, text]) => {
      return languagesToTranslate.map((language) => {
        const keyId = newKeys.find((k) => k.key === key)?.id
        if (!keyId) {
          throw new Error('Key not found')
        }
        return {
          keyId,
          targetLanguageCode: language.code,
          text
        }
      })
    })

    const allTranslatedItems = await batchTranslate({
      pageId,
      projectId,
      sourceLanguageCode,
      items
    })

    const sourceLanguageItems = Object.entries(itemsToTranslate).map(
      ([key, text]) => {
        const translationKeyId = newKeys.find((k) => k.key === key)?.id
        if (!translationKeyId) {
          throw new Error('Key not found')
        }
        return {
          pageId,
          projectId,
          value: text,
          translationKeyId,
          languageCode: sourceLanguageCode
        }
      }
    )

    const translationsToSave = [...sourceLanguageItems, ...allTranslatedItems]

    await db
      .insert(translations)
      .values(translationsToSave)
      .onConflictDoUpdate({
        target: [
          translations.pageId,
          translations.translationKeyId,
          translations.languageCode
        ],
        set: {
          value: sql`excluded.value`,
          updatedAt: new Date()
        }
      })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error in POST /translations:', error)
    return NextResponse.json(
      { error: (error as Error).message },
      { status: 400 }
    )
  }
}
