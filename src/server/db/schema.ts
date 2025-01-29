import {
  pgTable,
  uuid,
  timestamp,
  varchar,
  text,
  uniqueIndex,
  index
} from 'drizzle-orm/pg-core'

export const pages = pgTable(
  'pages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: varchar('name', { length: 255 }).notNull(),
    slug: varchar('slug', { length: 255 }).notNull().unique(),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow()
  },
  (t) => ({
    uniqueConstraint: uniqueIndex('pages_slug_idx').on(t.slug)
  })
)

export const languages = pgTable(
  'languages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    code: varchar('code', { length: 10 }).notNull().unique(), // ISO 639-1 codes (en, es, fr, etc.)
    name: varchar('name', { length: 255 }).notNull(),
    createdAt: timestamp('created_at').defaultNow()
  },
  (t) => ({
    uniqueConstraint: uniqueIndex('languages_code_idx').on(t.code)
  })
)

export const translationKeys = pgTable(
  'translation_keys',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    key: varchar('key', { length: 255 }).notNull(),
    description: text('description'),
    pageId: uuid('page_id').references(() => pages.id),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow()
  },
  (t) => ({
    keyIndex: index('translation_keys_key_idx').on(t.key)
  })
)

export const translations = pgTable(
  'translations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    translationKeyId: uuid('translation_key_id')
      .notNull()
      .references(() => translationKeys.id),
    languageId: uuid('language_id')
      .notNull()
      .references(() => languages.id),
    value: text('value').notNull(),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow()
  },
  (t) => ({
    uniqueConstraint: uniqueIndex('translations_key_lang_unique_idx').on(
      t.translationKeyId,
      t.languageId
    )
  })
)
