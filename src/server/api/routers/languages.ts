import { eq } from 'drizzle-orm'
import { z } from 'zod'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { languages } from '~/server/db/schema'

export const languagesRouter = createTRPCRouter({
  // Get all languages by project id
  getByProject: publicProcedure
    .input(z.object({ projectId: z.string() }))
    .query(({ ctx, input }) =>
      ctx.db
        .select()
        .from(languages)
        .where(eq(languages.projectId, input.projectId))
    ),

  // Create a new language
  create: publicProcedure
    .input(
      z.object({
        projectId: z.string(),
        code: z.string().min(2), // BCP 47 standard (e.g., 'en-US', 'es-ES')
        name: z.string(),
        isSource: z.boolean().optional()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .insert(languages)
        .values({
          projectId: input.projectId,
          code: input.code,
          name: input.name,
          isSource: input.isSource ?? false
        })
        .returning()
        .then((rows) => rows[0])
    }),

  // Set a language as source
  setAsSource: publicProcedure
    .input(z.object({ id: z.string(), projectId: z.string() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.transaction(async (tx) => {
        await tx
          .update(languages)
          .set({ isSource: false })
          .where(eq(languages.projectId, input.projectId))

        return await tx
          .update(languages)
          .set({ isSource: true })
          .where(eq(languages.id, input.id))
      })
    }),

  // Delete a language
  delete: publicProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.delete(languages).where(eq(languages.id, input.id))
    })
})
