import { translationsRouter } from '~/server/api/routers/translations'
import { translationKeysRouter } from '~/server/api/routers/translation-keys'
import { languagesRouter } from '~/server/api/routers/languages'
import { pagesRouter } from '~/server/api/routers/pages'
import { projectsRouter } from '~/server/api/routers/projects'
import { createCallerFactory, createTRPCRouter } from '~/server/api/trpc'
/**
 * This is the primary router for your server.
 *
 * All routers added in /api/routers should be manually added here.
 */
export const appRouter = createTRPCRouter({
  projects: projectsRouter,
  translations: translationsRouter,
  translationKeys: translationKeysRouter,
  languages: languagesRouter,
  pages: pagesRouter
})

// export type definition of API
export type AppRouter = typeof appRouter

/**
 * Create a server-side caller for the tRPC API.
 * @example
 * const trpc = createCaller(createContext);
 * const res = await trpc.post.all();
 *       ^? Post[]
 */
export const createCaller = createCallerFactory(appRouter)
