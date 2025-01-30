import { api } from '~/trpc/react'

const emptyRecord: Record<string, string> = {}

export const useNormalizedTranslationsByPage = (pageId: string | undefined) => {
  const { data: translations, isLoading } =
    api.translations.getAllByPageId.useQuery(
      { pageId: pageId ?? '' },
      {
        enabled: !!pageId,
        select: (data) => {
          return data.reduce((acc: Record<string, string>, translation) => {
            const id = `${translation.translationKeyId}_${translation.languageId}`
            acc[id] = translation.value ?? ''
            return acc
          }, emptyRecord)
        }
      }
    )

  return {
    isLoading,
    normalizedTranslations: translations ?? emptyRecord
  }
}
