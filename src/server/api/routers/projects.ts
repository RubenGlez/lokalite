import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { projects } from '~/server/db/schema'

export const projectsRouter = createTRPCRouter({
  // Get all projects
  getAll: publicProcedure.query(({ ctx }) => ctx.db.select().from(projects)),

  // Get a project by slug
  getBySlug: publicProcedure
    .input(z.object({ slug: z.string() }))
    .query(({ ctx, input }) =>
      ctx.db
        .select()
        .from(projects)
        .where(eq(projects.slug, input.slug))
        .then((res) => res[0])
    ),

  // Create a project
  create: publicProcedure
    .input(
      z.object({
        name: z.string(),
        slug: z.string()
      })
    )
    .mutation(({ ctx, input }) =>
      ctx.db
        .insert(projects)
        .values(input)
        .returning()
        .then((res) => res[0])
    )
})
