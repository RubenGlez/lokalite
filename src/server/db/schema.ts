import {
  pgTable,
  uuid,
  timestamp,
  varchar,
  text,
  unique,
  boolean,
  index,
  foreignKey
} from 'drizzle-orm/pg-core'
import { relations } from 'drizzle-orm'

// TABLES
export const projects = pgTable('projects', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 255 }).notNull(),
  slug: varchar('slug', { length: 255 }).notNull().unique(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow()
})

export const languages = pgTable(
  'languages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    projectId: uuid('project_id')
      .notNull()
      .references(() => projects.id, { onDelete: 'cascade' }),
    code: varchar('code', { length: 10 }).notNull(),
    name: varchar('name', { length: 255 }).notNull(),
    isSource: boolean('is_source').notNull().default(false),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow()
  },
  (table) => ({
    projectLanguageIdx: unique().on(table.projectId, table.code),
    nameIdx: index('name_idx').on(table.name)
  })
)

export const pages = pgTable(
  'pages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    projectId: uuid('project_id')
      .notNull()
      .references(() => projects.id, { onDelete: 'cascade' }),
    name: varchar('name', { length: 255 }).notNull(),
    slug: varchar('slug', { length: 255 }).notNull(),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow()
  },
  (table) => ({
    projectSlugIdx: unique().on(table.projectId, table.slug),
    projectIdIdx: index('project_id_idx').on(table.projectId)
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
      .references(() => pages.id, { onDelete: 'cascade' }),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow()
  },
  (table) => ({
    pageKeyIdx: unique().on(table.pageId, table.key),
    pageIdIdx: index('page_id_idx').on(table.pageId),
    keyIdx: index('key_idx').on(table.key)
  })
)

export const translations = pgTable(
  'translations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    translationKeyId: uuid('translation_key_id')
      .notNull()
      .references(() => translationKeys.id, { onDelete: 'cascade' }),
    pageId: uuid('page_id')
      .notNull()
      .references(() => pages.id, { onDelete: 'cascade' }),
    projectId: uuid('project_id')
      .notNull()
      .references(() => projects.id, { onDelete: 'cascade' }),
    languageCode: varchar('language_code', { length: 10 }).notNull(),
    value: text('value').notNull(),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow()
  },
  (table) => ({
    translationKeyLanguageIdx: unique().on(
      table.pageId,
      table.translationKeyId,
      table.languageCode
    ),
    translationKeyIdIdx: index('translation_key_id_idx').on(
      table.translationKeyId
    ),
    pageLanguageIdx: index('page_language_idx').on(
      table.pageId,
      table.languageCode
    ),
    languageCodeIdx: index('language_code_idx').on(table.languageCode),
    projectLanguageIdx: index('project_language_idx').on(
      table.projectId,
      table.languageCode
    ),
    languageCodeProjectIdFk: foreignKey({
      columns: [table.projectId, table.languageCode],
      foreignColumns: [languages.projectId, languages.code]
    }).onDelete('cascade')
  })
)

// RELATIONS
export const projectRelations = relations(projects, ({ many }) => ({
  pages: many(pages),
  languages: many(languages)
}))

export const languageRelations = relations(languages, ({ one, many }) => ({
  project: one(projects, {
    fields: [languages.projectId],
    references: [projects.id]
  }),
  translations: many(translations)
}))

export const pageRelations = relations(pages, ({ one, many }) => ({
  project: one(projects, {
    fields: [pages.projectId],
    references: [projects.id]
  }),
  translationKeys: many(translationKeys),
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
    fields: [translations.projectId, translations.languageCode],
    references: [languages.projectId, languages.code]
  }),
  project: one(projects, {
    fields: [translations.projectId],
    references: [projects.id]
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
