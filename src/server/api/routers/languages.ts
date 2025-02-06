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

  // Get a single language by ID
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db
        .select()
        .from(languages)
        .where(eq(languages.id, input.id))
        .then((rows) => rows[0]) // Return the first (and only) matching row
    }),

  // Create a new language
  create: publicProcedure
    .input(
      z.object({
        projectId: z.string(),
        code: z.string().min(2), // BCP 47 standard (e.g., 'en-US', 'es-ES')
        name: z.string()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .insert(languages)
        .values({
          projectId: input.projectId,
          code: input.code,
          name: input.name
        })
        .returning()
        .then((rows) => rows[0])
    }),

  // Delete a language
  delete: publicProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.delete(languages).where(eq(languages.id, input.id))
    })
})
