import { eq, desc, inArray } from 'drizzle-orm'
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
        .orderBy(desc(translationKeys.createdAt))
    }),

  upsertKey: publicProcedure
    .input(
      z.object({
        key: z.string(),
        pageId: z.string(),
        description: z.string().optional()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .insert(translationKeys)
        .values({
          key: input.key,
          pageId: input.pageId,
          description: input.description,
          updatedAt: new Date()
        })
        .onConflictDoUpdate({
          target: [translationKeys.id],
          set: {
            key: input.key,
            description: input.description,
            updatedAt: new Date()
          }
        })
    }),

  // Delete a single translation key (and its associated translations)
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
    }),

  // Delete multiple translation keys (and their associated translations)
  deleteKeys: publicProcedure
    .input(z.object({ ids: z.array(z.string()) }))
    .mutation(async ({ ctx, input }) => {
      // Delete all associated translations first
      await ctx.db
        .delete(translations)
        .where(inArray(translations.translationKeyId, input.ids))

      // Delete all translation keys
      return ctx.db
        .delete(translationKeys)
        .where(inArray(translationKeys.id, input.ids))
    })
})
