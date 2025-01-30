import { eq, asc } from 'drizzle-orm'
import { z } from 'zod'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { translationKeys, translations } from '~/server/db/schema'

export const translationKeysRouter = createTRPCRouter({
  // Get all translation keys by page id
  getAllByPageId: publicProcedure
    .input(z.object({ pageId: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db
        .select()
        .from(translationKeys)
        .where(eq(translationKeys.pageId, input.pageId))
        .orderBy(asc(translationKeys.updatedAt))
    }),

  upsertKey: publicProcedure
    .input(
      z.object({
        id: z.string().optional(),
        key: z.string(),
        pageId: z.string(),
        description: z.string().optional()
      })
    )
    .mutation(async ({ ctx, input }) => {
      if (input.id) {
        return ctx.db
          .update(translationKeys)
          .set({
            key: input.key,
            description: input.description,
            updatedAt: new Date()
          })
          .where(eq(translationKeys.id, input.id))
      }

      return ctx.db.insert(translationKeys).values({
        key: input.key,
        pageId: input.pageId,
        description: input.description
      })
    }),

  // Delete a translation key (and its associated translations)
  deleteKey: publicProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ ctx, input }) => {
      // Delete associated translations first
      await ctx.db
        .delete(translations)
        .where(eq(translations.translationKeyId, input.id))

      // Delete the translation key
      return ctx.db
        .delete(translationKeys)
        .where(eq(translationKeys.id, input.id))
    })
})
