import { api } from '~/trpc/server'
import {
  languages,
  pages,
  projects,
  translationKeys,
  translations
} from './schema'

export type Project = typeof projects.$inferSelect
export type NewProject = typeof projects.$inferInsert
export type Language = typeof languages.$inferSelect
export type NewLanguage = typeof languages.$inferInsert
export type Page = typeof pages.$inferSelect
export type NewPage = typeof pages.$inferInsert
export type TranslationKey = typeof translationKeys.$inferSelect
export type NewTranslationKey = typeof translationKeys.$inferInsert
export type Translation = typeof translations.$inferSelect
export type NewTranslation = typeof translations.$inferInsert

export type ComposedTranslation = Awaited<
  ReturnType<typeof api.translations.getAllByPageId>
>[number]
