'use client'

import { useCallback, useState } from 'react'
import { TranslationsTable } from '~/components/translations-table'
import { useNormalizedTranslationsByPage } from '~/hooks/use-normalized-translations-by-page'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { api } from '~/trpc/react'
import { useToast } from '~/hooks/use-toast'
import { ToastAction } from '~/components/ui/toast'

export default function PageDetail() {
  const [tableKey, setTableKey] = useState(0)
  const utils = api.useUtils()
  const page = useSelectedPage()
  const project = useSelectedProject()
  const { toast } = useToast()
  const { isLoading: isLoadingTranslations, normalizedTranslations } =
    useNormalizedTranslationsByPage(page?.id)

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
      utils.translations.invalidate()
    }
  })

  const deleteKeysAndTranslations = api.translationKeys.deleteKeys.useMutation({
    onSuccess: () => {
      utils.translationKeys.invalidate()
    }
  })

  const upsertTranslationKey = api.translationKeys.upsertKey.useMutation({
    onSuccess: () => {
      utils.translationKeys.invalidate()
    },
    onError: (_error, variables) => {
      toast({
        variant: 'destructive',
        title: 'Error updating a translation key',
        description: `The key ${variables.key} already exists. We recommend reloading the page.`,
        action: (
          <ToastAction
            altText="Reload"
            onClick={() => {
              window.location.reload()
            }}
          >
            Reload
          </ToastAction>
        )
      })
    }
  })

  const translate = api.translations.translate.useMutation({
    onSuccess: async () => {
      await utils.translations.invalidate()
      setTableKey((prev) => prev + 1)
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
        defaultLanguageId: project?.defaultLanguageId ?? ''
      })
    },
    [translate, page?.id, project?.id, project?.defaultLanguageId]
  )

  const handleCreated = useCallback(() => {
    setTableKey((prev) => prev + 1)
  }, [])

  if (isLoadingTranslationKeys || isLoadingLanguages || isLoadingTranslations) {
    return null
  }

  return (
    <div className="px-4">
      <TranslationsTable
        key={tableKey} // This is a hack to force the table to re-render
        onCreated={handleCreated}
        isTranslating={translate.isPending}
        data={translationKeys}
        languages={languages}
        normalizedTranslations={normalizedTranslations}
        onUpdateCell={handleUpdateCell}
        onDelete={handleDelete}
        onTranslate={handleTranslate}
        defaultLanguageId={project?.defaultLanguageId ?? ''}
        isDeleting={deleteKeysAndTranslations.isPending}
      />
    </div>
  )
}
