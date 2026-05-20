import { api } from '~/trpc/react'
import { useSelectedPage } from './use-selected-page'

export interface TranslationsTableRow {
  keyId: string
  keyValue: string
  translations: Record<string, string>
}

export function useTranslations() {
  const selectedPage = useSelectedPage()

  const pageId = selectedPage?.id ?? ''

  const { data: keys = [], isLoading: areKeysLoading } =
    api.translationKeys.getAllByPageId.useQuery(
      { pageId },
      {
        enabled: !!pageId
      }
    )

  const { data: translations, isLoading: areTranslationsLoading } =
    api.translations.getAllByPageId.useQuery(
      { pageId },
      {
        enabled: !!pageId,
        select: (data) => {
          return data.reduce(
            (acc: Record<string, Record<string, string>>, translation) => {
              if (!acc[translation.translationKeyId]) {
                acc[translation.translationKeyId] = {}
              }
              acc[translation.translationKeyId]![translation.languageCode] =
                translation.value ?? ''
              return acc
            },
            {}
          )
        }
      }
    )

  const data: TranslationsTableRow[] = keys?.map((key) => {
    return {
      keyId: key.id,
      keyValue: key.key,
      translations: translations?.[key.id] ?? {}
    }
  })

  const isLoading = areKeysLoading || areTranslationsLoading

  return { data, isLoading }
}
