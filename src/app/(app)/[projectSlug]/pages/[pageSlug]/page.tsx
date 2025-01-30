'use client'

import { TranslationsTable } from '~/components/translations-table'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { api } from '~/trpc/react'

export default function PageDetail() {
  const utils = api.useUtils()
  const page = useSelectedPage()
  const project = useSelectedProject()

  // const normalizedTranslations = useNormalizedTranslationsByPage(page?.id)

  const { data: languages, isLoading: isLoadingLanguages } =
    api.languages.getByProject.useQuery(
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

  const updateTranslationKey = api.translationKeys.updateKey.useMutation({
    onSuccess: () => {
      utils.translationKeys.getAllByPageId.invalidate()
    }
  })

  const handleUpdateCell = (
    translationKeyId: string | null,
    columnId: string,
    value: string
  ) => {
    if (!translationKeyId) return

    if (columnId === 'translationKey') {
      updateTranslationKey.mutate({
        id: translationKeyId,
        key: value
      })
    } else {
      const [languageCode] = columnId.split('_')
      const languageId = languages?.find(
        (language) => language.code === languageCode
      )?.id
      if (!languageId) return

      upsertTranslation.mutate({
        pageId: page?.id ?? '',
        languageId,
        translationKeyId,
        value
      })
    }
  }

  if (isLoadingLanguages || isLoadingTranslationKeys) {
    return <div>Loading...</div>
  }

  return (
    <div className="px-4">
      <TranslationsTable
        data={translationKeys}
        languages={languages}
        onUpdateCell={handleUpdateCell}
      />
    </div>
  )
}
