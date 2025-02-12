'use client'

import { useCallback, useMemo, useState } from 'react'
import { TranslationsEditor } from '~/components/translations-editor'
import { TranslationsTable } from '~/components/translations-table'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { useTranslations } from '~/hooks/use-translations'
import { api } from '~/trpc/react'

export default function PageDetail() {
  const [keysToEdit, setKeysToEdit] = useState<string[]>([])
  const utils = api.useUtils()
  const page = useSelectedPage()
  const project = useSelectedProject()

  const { data, isLoading } = useTranslations()

  const { data: languages = [], isLoading: isLoadingLanguages } =
    api.languages.getByProject.useQuery(
      {
        projectId: project?.id ?? ''
      },
      { enabled: !!project?.id }
    )

  const sourceLanguage = useMemo(
    () => languages?.find((language) => language.isSource),
    [languages]
  )

  const deleteKeysAndTranslations = api.translationKeys.deleteKeys.useMutation({
    onSuccess: () => {
      utils.translationKeys.invalidate()
    }
  })

  const translate = api.translations.translate.useMutation({
    onSuccess: async () => {
      utils.translations.invalidate()
    }
  })

  const handleDelete = useCallback(
    (translationKeyIds: string[]) => {
      deleteKeysAndTranslations.mutate({
        ids: translationKeyIds
      })
    },
    [deleteKeysAndTranslations]
  )

  const handleTranslate = useCallback(
    (translationKeyIds: string[]) => {
      translate.mutate({
        projectId: project?.id ?? '',
        pageId: page?.id ?? '',
        translationKeyIds,
        sourceLanguageCode: sourceLanguage?.code ?? ''
      })
    },
    [translate, page?.id, project?.id, sourceLanguage?.code]
  )

  const handleEdit = useCallback((translationKeyIds: string[]) => {
    setKeysToEdit(translationKeyIds)
  }, [])

  if (isLoading || isLoadingLanguages) {
    return null
  }

  return (
    <div className="flex flex-col max-h-[calc(100svh-theme(spacing.16))] px-4">
      <TranslationsTable
        data={data}
        onDelete={handleDelete}
        isDeleting={deleteKeysAndTranslations.isPending}
        onTranslate={handleTranslate}
        isTranslating={translate.isPending}
        onEdit={handleEdit}
        languages={languages}
      />

      <TranslationsEditor translationKeyIds={keysToEdit} />
    </div>
  )
}
