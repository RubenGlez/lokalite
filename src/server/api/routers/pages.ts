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
    })
})
