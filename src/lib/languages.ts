import { Language } from '~/server/db/schema'

export const availableLanguages: Pick<Language, 'name' | 'code'>[] = [
  { name: 'Mandarin Chinese', code: 'zh-CN' },
  { name: 'Spanish', code: 'es-ES' },
  { name: 'English', code: 'en-US' },
  { name: 'Hindi', code: 'hi-IN' },
  { name: 'Bengali', code: 'bn-BD' },
  { name: 'Portuguese', code: 'pt-BR' },
  { name: 'Russian', code: 'ru-RU' },
  { name: 'Japanese', code: 'ja-JP' },
  { name: 'Western Punjabi', code: 'pa-PK' },
  { name: 'Marathi', code: 'mr-IN' },
  { name: 'Telugu', code: 'te-IN' },
  { name: 'Wu Chinese (Shanghainese)', code: 'zh-CN-shanghainese' },
  { name: 'Turkish', code: 'tr-TR' },
  { name: 'Korean', code: 'ko-KR' },
  { name: 'French', code: 'fr-FR' },
  { name: 'German', code: 'de-DE' },
  { name: 'Vietnamese', code: 'vi-VN' },
  { name: 'Tamil', code: 'ta-IN' },
  { name: 'Urdu', code: 'ur-PK' },
  { name: 'Italian', code: 'it-IT' },
  { name: 'Yue Chinese (Cantonese)', code: 'zh-HK' },
  { name: 'Thai', code: 'th-TH' },
  { name: 'Gujarati', code: 'gu-IN' },
  { name: 'Javanese', code: 'jv-ID' },
  { name: 'Persian (Farsi)', code: 'fa-IR' },
  { name: 'Polish', code: 'pl-PL' },
  { name: 'Pashto', code: 'ps-AF' },
  { name: 'Kannada', code: 'kn-IN' },
  { name: 'Malayalam', code: 'ml-IN' },
  { name: 'Sundanese', code: 'su-ID' },
  { name: 'Hausa', code: 'ha-NG' },
  { name: 'Burmese', code: 'my-MM' },
  { name: 'Ukrainian', code: 'uk-UA' },
  { name: 'Hebrew', code: 'he-IL' },
  { name: 'Dutch', code: 'nl-NL' },
  { name: 'Romanian', code: 'ro-RO' },
  { name: 'Hakka Chinese', code: 'zh-TW-hakka' },
  { name: 'Tagalog (Filipino)', code: 'tl-PH' },
  { name: 'Hungarian', code: 'hu-HU' },
  { name: 'Greek', code: 'el-GR' }
]

export const availableLanguagesByCode = availableLanguages.reduce(
  (acc, lang) => {
    acc[lang.code] = lang
    return acc
  },
  {} as Record<string, (typeof availableLanguages)[number]>
)
