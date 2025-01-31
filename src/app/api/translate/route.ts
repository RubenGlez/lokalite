import { openai } from '@ai-sdk/openai'
import { generateObject } from 'ai'
import { not } from 'drizzle-orm'
import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { db } from '~/server/db'
import { translations as translationsTable } from '~/server/db/schema'

interface TranslationBody {
  projectId: string
  pageId: string
  translationKeyIds: string[]
  defaultLanguageId: string
}

interface TranslationInput {
  keyId: string
  targetLanguageCode: string
  targetLanguageId: string
  text: string
}

interface TranslationOutput {
  pageId: string
  translationKeyId: string
  languageId: string
  value: string
}

const translationSchema = z.object({
  list: z.array(
    z.object({
      pageId: z.string().describe('The page id of the translation'),
      translationKeyId: z.string().describe('The translation key id'),
      languageId: z.string().describe('The language id of the translation'),
      value: z.string().describe('The translated text')
    })
  )
})

export async function POST(req: NextRequest) {
  try {
    const { projectId, pageId, translationKeyIds, defaultLanguageId } =
      (await req.json()) as TranslationBody

    // Fetch translations and languages in parallel for better performance
    const [translations, languages] = await Promise.all([
      db.query.translations.findMany({
        where: (translations, { eq, and, inArray }) =>
          and(
            eq(translations.pageId, pageId),
            inArray(translations.translationKeyId, translationKeyIds)
          )
      }),
      db.query.languages.findMany({
        where: (languages, { eq, and }) =>
          and(
            eq(languages.projectId, projectId),
            not(eq(languages.id, defaultLanguageId))
          )
      })
    ])

    const defaultTranslations = translations.filter(
      (t) => t.languageId === defaultLanguageId
    )

    const translationInputs: TranslationInput[] = defaultTranslations.flatMap(
      (translation) =>
        languages.map((language) => ({
          keyId: translation.translationKeyId,
          targetLanguageCode: language.code,
          targetLanguageId: language.id,
          text: translation.value
        }))
    )

    const { object } = await generateObject({
      model: openai('gpt-4-turbo'),
      schema: translationSchema,
      system: createSystemPrompt(pageId),
      prompt: `These is the list of translations to translate: ${JSON.stringify(
        translationInputs,
        null,
        2
      )}`
    })

    await upsertTranslations(object.list)

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[TRANSLATE_ERROR]', error)
    return NextResponse.json(
      { error: 'Failed to process translation' },
      { status: 500 }
    )
  }
}

function createSystemPrompt(pageId: string): string {
  return [
    'You are a helpful assistant that translates text from one language to another.',
    'You are going to receive a list of objects with the following properties:',
    '- keyId: The key id of the translation',
    '- targetLanguageCode: The code of the language to translate to (in format ISO 639-1)',
    '- targetLanguageId: The id of the language to translate to',
    '- text: The text to translate',
    'Guidelines:',
    '- You will need to translate the text to the target language.',
    '- You will need to return a list of objects with the pageId, translationKeyId, languageId, and the translated text.',
    `- The pageId is: ${pageId} (same for all objects)`
  ].join('\n')
}

async function upsertTranslations(translations: TranslationOutput[]) {
  return Promise.all(
    translations.map((translation) =>
      db
        .insert(translationsTable)
        .values({
          ...translation,
          updatedAt: new Date()
        })
        .onConflictDoUpdate({
          target: [
            translationsTable.pageId,
            translationsTable.translationKeyId,
            translationsTable.languageId
          ],
          set: {
            value: translation.value,
            updatedAt: new Date()
          }
        })
    )
  )
}
