import { eq, not, sql } from 'drizzle-orm'
import { z } from 'zod'
import { translate } from '~/lib/translation-agent'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { translationKeys, translations } from '~/server/db/schema'

const BATCH_SIZE = 150 // This is hardcoded but can be adjusted based on the token limit requirements

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

  // Create a full translation
  createFullTranslation: publicProcedure
    .input(
      z.object({
        pageId: z.string().uuid(),
        key: z.string().min(1),
        translations: z.record(z.string().min(2), z.string().min(1)),
        projectId: z.string().uuid()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db.transaction(async (tx) => {
        const keyCreated = await tx
          .insert(translationKeys)
          .values({
            key: input.key,
            pageId: input.pageId
          })
          .returning({ id: translationKeys.id })
          .then((res) => res[0])

        if (!keyCreated) {
          tx.rollback()
          throw new Error('Failed to create translation key')
        }

        return tx.insert(translations).values(
          Object.entries(input.translations).map(([languageCode, value]) => ({
            languageCode,
            value,
            pageId: input.pageId,
            translationKeyId: keyCreated.id,
            projectId: input.projectId
          }))
        )
      })
    }),

  // Create or update a translation
  upsertTranslation: publicProcedure
    .input(
      z.object({
        pageId: z.string().uuid(),
        translationKeyId: z.string().uuid(),
        languageCode: z.string(),
        value: z.string(),
        projectId: z.string().uuid()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .insert(translations)
        .values({
          pageId: input.pageId,
          translationKeyId: input.translationKeyId,
          languageCode: input.languageCode,
          value: input.value,
          projectId: input.projectId,
          updatedAt: new Date()
        })
        .onConflictDoUpdate({
          target: [
            translations.pageId,
            translations.translationKeyId,
            translations.languageCode
          ],
          set: {
            value: input.value,
            updatedAt: new Date()
          }
        })
    }),

  // Translate a list of translations
  translate: publicProcedure
    .input(
      z.object({
        projectId: z.string(),
        pageId: z.string(),
        translationKeyIds: z.array(z.string()),
        defaultLanguageCode: z.string()
      })
    )
    .mutation(async ({ input, ctx }) => {
      const [currentTranslations, languages] = await Promise.all([
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
              not(eq(languages.code, input.defaultLanguageCode))
            )
        })
      ])

      const sourceTranslations = currentTranslations.filter(
        (t) => t.languageCode === input.defaultLanguageCode
      )

      const itemsToTranslate = sourceTranslations.flatMap((item) =>
        languages.map((language) => ({
          keyId: item.translationKeyId,
          targetLanguageCode: language.code,
          targetLanguageId: language.id,
          text: item.value
        }))
      )

      // Process translations in batches
      const allTranslatedItems = []
      for (let i = 0; i < itemsToTranslate.length; i += BATCH_SIZE) {
        const batch = itemsToTranslate.slice(i, i + BATCH_SIZE)
        const translatedBatch = await translate(
          input.projectId,
          input.pageId,
          input.defaultLanguageCode,
          batch
        )
        allTranslatedItems.push(...translatedBatch)
      }

      return ctx.db
        .insert(translations)
        .values(allTranslatedItems)
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
    })
})
