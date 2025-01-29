import {
  languages,
  pages,
  projects,
  translationKeys,
  translations
} from './schema'

export type Project = typeof projects.$inferSelect
export type Language = typeof languages.$inferSelect
export type Page = typeof pages.$inferSelect
export type TranslationKey = typeof translationKeys.$inferSelect
export type Translation = typeof translations.$inferSelect

export type ComposedTranslation = {
  key: string
  description: string | null
  language: string | null
  value: string | null
}
