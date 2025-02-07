import { eq, and, not } from 'drizzle-orm'
import { z } from 'zod'
import { translate } from '~/lib/translation-agent'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { translationKeys, translations } from '~/server/db/schema'

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

  // Create multiple translations
  createMultiple: publicProcedure
    .input(
      z.object({
        pageId: z.string().uuid(),
        key: z.string().min(1),
        translations: z.record(z.string().min(2), z.string().min(1))
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

        console.log('keyCreated', keyCreated)

        return tx.insert(translations).values(
          Object.entries(input.translations).map(([languageId, value]) => ({
            languageId,
            value,
            translationKeyId: keyCreated.id,
            pageId: input.pageId
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
      const [trans, languages] = await Promise.all([
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

      const defaultTranslations = trans.filter(
        (t) => t.languageId === input.defaultLanguageId
      )

      const itemsToTranslate = defaultTranslations.flatMap((item) =>
        languages.map((language) => ({
          keyId: item.translationKeyId,
          targetLanguageCode: language.code,
          targetLanguageId: language.id,
          text: item.value
        }))
      )

      const translatedItems = await translate(input.pageId, itemsToTranslate)

      return Promise.all(
        translatedItems.map((item) =>
          ctx.db
            .insert(translations)
            .values(item)
            .onConflictDoUpdate({
              target: [
                translations.pageId,
                translations.translationKeyId,
                translations.languageId
              ],
              set: {
                value: item.value,
                updatedAt: new Date()
              }
            })
        )
      )
    })
})
