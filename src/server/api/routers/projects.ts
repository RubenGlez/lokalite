import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { createTRPCRouter, publicProcedure } from '~/server/api/trpc'
import { projects } from '~/server/db/schema'

export const projectsRouter = createTRPCRouter({
  // Get all projects
  getAll: publicProcedure.query(({ ctx }) => ctx.db.select().from(projects)),

  // Get a project by id
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(({ ctx, input }) =>
      ctx.db
        .select()
        .from(projects)
        .where(eq(projects.id, input.id))
        .then((res) => res[0])
    ),

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
    .input(z.object({ name: z.string(), slug: z.string() }))
    .mutation(({ ctx, input }) => ctx.db.insert(projects).values(input)),

  // Update a project
  update: publicProcedure
    .input(
      z.object({
        id: z.string(),
        name: z.string().optional(),
        slug: z.string().optional(),
        defaultLanguageId: z.string().optional()
      })
    )
    .mutation(({ ctx, input }) =>
      ctx.db.update(projects).set(input).where(eq(projects.id, input.id))
    ),

  // Delete a project
  delete: publicProcedure
    .input(z.object({ id: z.string() }))
    .mutation(({ ctx, input }) =>
      ctx.db.delete(projects).where(eq(projects.id, input.id))
    )
})
