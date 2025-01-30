import { pgTable, uuid, timestamp, varchar, text } from 'drizzle-orm/pg-core'
import { relations } from 'drizzle-orm'

// TABLES
export const projects = pgTable('projects', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 255 }).notNull(),
  slug: varchar('slug', { length: 255 }).notNull().unique(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
})

export const pages = pgTable('pages', {
  id: uuid('id').primaryKey().defaultRandom(),
  projectId: uuid('project_id')
    .notNull()
    .references(() => projects.id),
  name: varchar('name', { length: 255 }).notNull(),
  slug: varchar('slug', { length: 255 }).notNull().unique(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
})

export const languages = pgTable('languages', {
  id: uuid('id').primaryKey().defaultRandom(),
  projectId: uuid('project_id')
    .notNull()
    .references(() => projects.id),
  code: varchar('code', { length: 10 }).notNull().unique(), // ISO 639-1 codes (en, es, fr, etc.)
  name: varchar('name', { length: 255 }).notNull(),
  createdAt: timestamp('created_at').defaultNow()
})

export const translationKeys = pgTable('translation_keys', {
  id: uuid('id').primaryKey().defaultRandom(),
  key: varchar('key', { length: 255 }).notNull(),
  description: text('description'),
  pageId: uuid('page_id').references(() => pages.id),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
})

export const translations = pgTable('translations', {
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
  updatedAt: timestamp('updated_at').defaultNow()
})

// RELATIONS
export const projectRelations = relations(projects, ({ many }) => ({
  pages: many(pages),
  languages: many(languages)
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
