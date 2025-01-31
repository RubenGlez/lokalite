import {
  pgTable,
  uuid,
  timestamp,
  varchar,
  text,
  unique
} from 'drizzle-orm/pg-core'
import { relations } from 'drizzle-orm'

// TABLES
export const projects = pgTable('projects', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 255 }).notNull(),
  slug: varchar('slug', { length: 255 }).notNull().unique(),
  defaultLanguageId: uuid('default_language_id').references(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (): any => languages.id
  ),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at')
})

export const pages = pgTable(
  'pages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    projectId: uuid('project_id')
      .notNull()
      .references(() => projects.id),
    name: varchar('name', { length: 255 }).notNull(),
    slug: varchar('slug', { length: 255 }).notNull().unique(),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at')
  },
  (table) => ({
    projectSlugIdx: unique().on(table.projectId, table.slug)
  })
)
export const languages = pgTable(
  'languages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    projectId: uuid('project_id')
      .notNull()
      .references(() => projects.id),
    code: varchar('code', { length: 10 }).notNull().unique(),
    name: varchar('name', { length: 255 }).notNull(),
    createdAt: timestamp('created_at').defaultNow()
  },
  (table) => ({
    projectCodeIdx: unique().on(table.projectId, table.code)
  })
)

export const translationKeys = pgTable(
  'translation_keys',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    key: varchar('key', { length: 255 }).notNull(),
    description: text('description'),
    pageId: uuid('page_id')
      .notNull()
      .references(() => pages.id),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at')
  },
  (table) => ({
    pageKeyIdx: unique().on(table.pageId, table.key)
  })
)

export const translations = pgTable(
  'translations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    translationKeyId: uuid('translation_key_id')
      .notNull()
      .references(() => translationKeys.id),
    pageId: uuid('page_id')
      .notNull()
      .references(() => pages.id),
    languageId: uuid('language_id')
      .notNull()
      .references(() => languages.id),
    value: text('value').notNull(),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at')
  },
  (table) => ({
    translationKeyLanguageIdx: unique().on(
      table.pageId,
      table.translationKeyId,
      table.languageId
    )
  })
)

// RELATIONS
export const projectRelations = relations(projects, ({ many, one }) => ({
  pages: many(pages),
  languages: many(languages),
  defaultLanguage: one(languages, {
    fields: [projects.defaultLanguageId],
    references: [languages.id]
  })
}))

export const pageRelations = relations(pages, ({ one, many }) => ({
  project: one(projects, {
    fields: [pages.projectId],
    references: [projects.id]
  }),
  translationKeys: many(translationKeys),
  translations: many(translations)
}))

export const languageRelations = relations(languages, ({ one, many }) => ({
  project: one(projects, {
    fields: [languages.projectId],
    references: [projects.id]
  }),
  translations: many(translations)
}))

export const translationKeyRelations = relations(
  translationKeys,
  ({ one, many }) => ({
    page: one(pages, {
      fields: [translationKeys.pageId],
      references: [pages.id]
    }),
    translations: many(translations)
  })
)

export const translationRelations = relations(translations, ({ one }) => ({
  translationKey: one(translationKeys, {
    fields: [translations.translationKeyId],
    references: [translationKeys.id]
  }),
  page: one(pages, {
    fields: [translations.pageId],
    references: [pages.id]
  }),
  language: one(languages, {
    fields: [translations.languageId],
    references: [languages.id]
  })
}))

// TYPES
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
