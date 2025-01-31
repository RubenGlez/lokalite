import { z } from 'zod'
import { db } from '~/server/db'
import { translations as translationsTable } from '~/server/db/schema'

interface TranslationOutput {
  pageId: string
  translationKeyId: string
  languageId: string
  value: string
}

export const translationSchema = z.object({
  list: z.array(
    z.object({
      pageId: z.string().describe('The page id of the translation'),
      translationKeyId: z.string().describe('The translation key id'),
      languageId: z.string().describe('The language id of the translation'),
      value: z.string().describe('The translated text')
    })
  )
})

export function createSystemPrompt(pageId: string): string {
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

export async function upsertTranslations(translations: TranslationOutput[]) {
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
