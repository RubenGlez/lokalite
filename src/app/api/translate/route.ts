import { openai } from '@ai-sdk/openai'
import { generateObject } from 'ai'
import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'

export interface TranslationBody {
  id: string
  keyId: string
  languageCode: string
  text: string
}

// Allow streaming responses up to 30 seconds
export const maxDuration = 30

export async function POST(req: NextRequest) {
  const { data } = await req.json()

  const translationList = data as TranslationBody[]

  console.log('>>[TRANSLATE]', translationList)

  const { object } = await generateObject({
    model: openai('gpt-4-turbo'),
    schema: z.object({
      list: z.array(
        z.object({
          id: z.string().describe('The id of the translation'),
          keyId: z.string().describe('The key id of the translation'),
          translation: z.string().describe('The translated text')
        })
      )
    }),
    system: [
      'You are a helpful assistant that translates text from one language to another.',
      'Guidelines:',
      '- Use the "languageCode" to translate the text to the correct language.',
      '- Use the "text" to translate the text to the correct value.',
      '- You will be given a list of translations and you will need to translate the text to the target language.',
      '- You will need to return a list of objects with the id, keyId, and the translated text.'
    ].join('\n'),
    prompt:
      'These are the translations to translate: ' +
      JSON.stringify(translationList, null, 2)
  })

  console.log('<<[TRANSLATE]', object)

  return NextResponse.json(object)
}
