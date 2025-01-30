import { eq } from 'drizzle-orm'
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
    }),

  // Create a new translation key
  createKey: publicProcedure
    .input(
      z.object({
        projectId: z.string(),
        pageId: z.string(),
        key: z.string(),
        description: z.string().optional()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db.insert(translationKeys).values({
        pageId: input.pageId,
        key: input.key,
        description: input.description
      })
    }),

  // Update a translation key
  updateKey: publicProcedure
    .input(
      z.object({
        id: z.string(),
        key: z.string().optional(),
        description: z.string().optional()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .update(translationKeys)
        .set({
          key: input.key,
          description: input.description
        })
        .where(eq(translationKeys.id, input.id))
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
