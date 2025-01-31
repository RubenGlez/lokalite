import { openai } from '@ai-sdk/openai'
import { generateObject } from 'ai'
import { eq, and, not } from 'drizzle-orm'
import { z } from 'zod'
import { createSystemPrompt, upsertTranslations } from '~/lib/translation-agent'
import { translationSchema } from '~/lib/translation-agent'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { translations } from '~/server/db/schema'

export const translationsRouter = createTRPCRouter({
  // Get all translations for a specific page
  getAllByPageId: publicProcedure
    .input(z.object({ pageId: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db
        .select()
        .from(translations)
        .where(eq(translations.pageId, input.pageId))
    }),

  // Create or update a translation
  upsertTranslation: publicProcedure
    .input(
      z.object({
        pageId: z.string().uuid(),
        translationKeyId: z.string().uuid(),
        languageId: z.string().uuid(),
        value: z.string()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .insert(translations)
        .values({
          pageId: input.pageId,
          translationKeyId: input.translationKeyId,
          languageId: input.languageId,
          value: input.value,
          updatedAt: new Date()
        })
        .onConflictDoUpdate({
          target: [
            translations.pageId,
            translations.translationKeyId,
            translations.languageId
          ],
          set: {
            value: input.value,
            updatedAt: new Date()
          }
        })
    }),

  // Delete a translation
  deleteTranslation: publicProcedure
    .input(
      z.object({
        translationKeyId: z.string(),
        languageId: z.string()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .delete(translations)
        .where(
          and(
            eq(translations.translationKeyId, input.translationKeyId),
            eq(translations.languageId, input.languageId)
          )
        )
    }),

  // Translate a list of translations
  translate: publicProcedure
    .input(
      z.object({
        projectId: z.string(),
        pageId: z.string(),
        translationKeyIds: z.array(z.string()),
        defaultLanguageId: z.string()
      })
    )
    .mutation(async ({ input, ctx }) => {
      const [translations, languages] = await Promise.all([
        ctx.db.query.translations.findMany({
          where: (translations, { eq, and, inArray }) =>
            and(
              eq(translations.pageId, input.pageId),
              inArray(translations.translationKeyId, input.translationKeyIds)
            )
        }),
        ctx.db.query.languages.findMany({
          where: (languages, { eq, and }) =>
            and(
              eq(languages.projectId, input.projectId),
              not(eq(languages.id, input.defaultLanguageId))
            )
        })
      ])

      const defaultTranslations = translations.filter(
        (t) => t.languageId === input.defaultLanguageId
      )

      const translationInputs = defaultTranslations.flatMap((translation) =>
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
        system: createSystemPrompt(input.pageId),
        prompt: `These is the list of translations to translate: ${JSON.stringify(
          translationInputs,
          null,
          2
        )}`
      })

      return await upsertTranslations(object.list)
    })
})
