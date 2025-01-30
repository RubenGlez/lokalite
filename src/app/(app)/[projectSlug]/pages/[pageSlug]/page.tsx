'use client'

import { useCallback } from 'react'
import { TranslationsTable } from '~/components/translations-table'
import { useNormalizedTranslationsByPage } from '~/hooks/use-normalized-translations-by-page'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { api } from '~/trpc/react'

export default function PageDetail() {
  const utils = api.useUtils()
  const page = useSelectedPage()
  const project = useSelectedProject()

  const normalizedTranslations = useNormalizedTranslationsByPage(page?.id)

  const { data: languages } = api.languages.getByProject.useQuery(
    {
      projectId: project?.id ?? ''
    },
    { enabled: !!project?.id }
  )

  const { data: translationKeys, isLoading: isLoadingTranslationKeys } =
    api.translationKeys.getAllByPageId.useQuery(
      {
        pageId: page?.id ?? ''
      },
      { enabled: !!page?.id }
    )

  const upsertTranslation = api.translations.upsertTranslation.useMutation({
    onSuccess: () => {
      utils.translations.getAllByPageId.invalidate()
    }
  })

  const upsertTranslationKey = api.translationKeys.upsertKey.useMutation({
    onSuccess: () => {
      utils.translationKeys.getAllByPageId.invalidate()
    }
  })

  const getLanguageId = useCallback(
    (languageCode: string) =>
      languages?.find((language) => language.code === languageCode)?.id,
    [languages]
  )

  const handleUpsertTranslation = useCallback(
    (params: {
      pageId: string
      languageCode: string
      translationKeyId: string
      value: string
    }) => {
      const languageId = getLanguageId(params.languageCode)
      if (!languageId) return
      upsertTranslation.mutate({
        ...params,
        languageId
      })
    },
    [upsertTranslation, getLanguageId]
  )

  const handleUpsertTranslationKey = useCallback(
    (params: { id?: string; key: string; pageId: string }) => {
      upsertTranslationKey.mutate(params)
    },
    [upsertTranslationKey]
  )

  const handleUpdateCell = useCallback(
    (translationKeyId: string | null, columnId: string, value: string) => {
      if (!translationKeyId || !page?.id) return

      if (columnId === 'key') {
        handleUpsertTranslationKey({
          id: translationKeyId,
          key: value,
          pageId: page.id
        })
      } else {
        handleUpsertTranslation({
          pageId: page.id,
          languageCode: columnId,
          translationKeyId,
          value
        })
      }
    },
    [page?.id, handleUpsertTranslation, handleUpsertTranslationKey]
  )

  if (isLoadingTranslationKeys) return null

  return (
    <div className="px-4">
      <TranslationsTable
        data={translationKeys}
        languages={languages}
        normalizedTranslations={normalizedTranslations}
        onUpdateCell={handleUpdateCell}
      />
    </div>
  )
}
