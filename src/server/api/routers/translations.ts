import { eq, and } from 'drizzle-orm'
import { z } from 'zod'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { languages, translationKeys, translations } from '~/server/db/schema'

export const translationsRouter = createTRPCRouter({
  // Get all translations for a specific page
  getAllByPageId: publicProcedure
    .input(z.object({ pageId: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db
        .select({
          key: translationKeys.key,
          description: translationKeys.description,
          language: languages.code,
          value: translations.value
        })
        .from(translationKeys)
        .where(eq(translationKeys.pageId, input.pageId))
        .leftJoin(
          translations,
          eq(translationKeys.id, translations.translationKeyId)
        )
        .leftJoin(languages, eq(translations.languageId, languages.id))
    }),

  // Create or update a translation
  upsertTranslation: publicProcedure
    .input(
      z.object({
        translationKeyId: z.string(),
        languageId: z.string(),
        value: z.string()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .insert(translations)
        .values({
          translationKeyId: input.translationKeyId,
          languageId: input.languageId,
          value: input.value
        })
        .onConflictDoUpdate({
          target: [translations.translationKeyId, translations.languageId],
          set: { value: input.value }
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
    })
})
