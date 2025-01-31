import { eq } from 'drizzle-orm'
import { z } from 'zod'

import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { pages } from '~/server/db/schema'

export const pagesRouter = createTRPCRouter({
  // Get all pages by project id
  getByProject: publicProcedure
    .input(z.object({ projectId: z.string() }))
    .query(({ ctx, input }) =>
      ctx.db.select().from(pages).where(eq(pages.projectId, input.projectId))
    ),

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

  // Get a single page by slug
  getBySlug: publicProcedure
    .input(z.object({ slug: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.db
        .select()
        .from(pages)
        .where(eq(pages.slug, input.slug))
        .then((rows) => rows[0]) // Return the first (and only) matching row
    }),

  // Create a new page
  create: publicProcedure
    .input(
      z.object({
        name: z.string(),
        slug: z.string(),
        projectId: z.string()
      })
    )
    .mutation(async ({ ctx, input }) => {
      return ctx.db.insert(pages).values({
        name: input.name,
        slug: input.slug,
        projectId: input.projectId
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
