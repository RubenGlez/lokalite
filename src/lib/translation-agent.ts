import { generateObject } from 'ai'
import { openai } from '@ai-sdk/openai'
import { z } from 'zod'

const translationSchema = z.object({
  list: z.array(
    z.object({
      projectId: z.string().describe('The project id of the translation'),
      pageId: z.string().describe('The page id of the translation'),
      translationKeyId: z.string().describe('The translation key id'),
      languageCode: z.string().describe('The language code of the translation'),
      value: z.string().describe('The translated text')
    })
  )
})

interface ItemToTranslate {
  keyId: string
  targetLanguageCode: string
  text: string
}

export async function translate(
  projectId: string,
  pageId: string,
  sourceLanguageCode: string,
  itemsToTranslate: ItemToTranslate[]
) {
  if (itemsToTranslate.length === 0) {
    return []
  }

  const { object } = await generateObject({
    model: openai('gpt-4-turbo'),
    schema: translationSchema,
    system: [
      'You are a helpful assistant that translates text from one language to another.',
      'You are going to receive a list of objects with the following properties:',
      '- keyId: The key id of the translation',
      '- targetLanguageCode: The code of the language to translate to (in standard BCP 47 format)',
      '- text: The text to translate',
      'Guidelines:',
      '- You will need to translate the text to the target language.',
      '- You will need to return a list of objects with the projectId, pageId, translationKeyId, languageCode, and the translated text.',
      `- The projectId is: ${projectId} (same for all objects)`,
      `- The pageId is: ${pageId} (same for all objects)`,
      `- The source language code is: ${sourceLanguageCode} (same for all objects)`
    ].join('\n'),
    prompt: `This is the list of translations to translate: ${JSON.stringify(
      itemsToTranslate,
      null,
      2
    )}`
  })
  return object.list
}
