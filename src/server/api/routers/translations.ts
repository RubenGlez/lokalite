import { eq, and } from 'drizzle-orm'
import { z } from 'zod'

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
          value: input.value
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
    })
})
