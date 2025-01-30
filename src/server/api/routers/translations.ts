import { eq, and } from 'drizzle-orm'
import { z } from 'zod'
import { env } from '~/env'

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
    }),

  translateSome: publicProcedure
    .input(
      z.object({
        pageId: z.string(),
        translationKeyIds: z.array(z.string())
      })
    )
    .mutation(async ({ ctx, input }) => {
      // Similar logic as translateRow but for multiple keys
      const keys = await ctx.db.query.translationKeys.findMany({
        where: (keys, { eq, and, inArray }) =>
          and(
            eq(keys.pageId, input.pageId),
            inArray(keys.id, input.translationKeyIds)
          ),
        with: {
          translations: {
            with: {
              language: true
            }
          }
        }
      })

      const translationList = keys.flatMap((key) =>
        key.translations.map((t) => ({
          id: t.id,
          keyId: key.id,
          languageCode: t.language.code,
          text: t.value
        }))
      )

      const response = await fetch(`${env.NEXT_PUBLIC_APP_URL}/api/translate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ data: translationList })
      })

      const { list } = await response.json()

      for (const item of list) {
        await ctx.db
          .update(translations)
          .set({
            value: item.translation,
            updatedAt: new Date()
          })
          .where(eq(translations.id, item.id))
      }
    })
})
