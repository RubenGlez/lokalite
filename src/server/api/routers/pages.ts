import { eq } from 'drizzle-orm'
import { z } from 'zod'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { pages } from '~/server/db/schema'

export const pagesRouter = createTRPCRouter({
  // Get all pages
  getAll: publicProcedure.query(async ({ ctx }) => {
    return ctx.db.select().from(pages)
  }),

  // Get a single page by ID
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db
        .select()
        .from(pages)
        .where(eq(pages.id, input.id))
        .then((rows) => rows[0]) // Return the first (and only) matching row
    }),

  // Create a new page
  create: publicProcedure
    .input(
      z.object({
        name: z.string(),
        slug: z.string()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db.insert(pages).values({
        name: input.name,
        slug: input.slug
      })
    }),

  // Update a page
  update: publicProcedure
    .input(
      z.object({
        id: z.string(),
        name: z.string().optional(),
        slug: z.string().optional()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db
        .update(pages)
        .set({
          name: input.name,
          slug: input.slug
        })
        .where(eq(pages.id, input.id))
    }),

  // Delete a page
  delete: publicProcedure
    .input(z.object({ id: z.string() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.delete(pages).where(eq(pages.id, input.id))
    })
})
