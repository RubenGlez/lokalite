'use client'

import { useCallback } from 'react'
import { TranslationsTable } from '~/components/translations-table'
import { useNormalizedTranslationsByPage } from '~/hooks/use-normalized-translations-by-page'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { api } from '~/trpc/react'
import { useToast } from '~/hooks/use-toast'
import { ToastAction } from '~/components/ui/toast'
import { useHotkeys } from 'react-hotkeys-hook'

export default function PageDetail() {
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
      utils.translations.getAllByPageId.invalidate()
    }
  })

  const deleteTranslationKey = api.translationKeys.deleteKey.useMutation({
    onSuccess: () => {
      utils.translationKeys.getAllByPageId.invalidate()
    }
  })

  const upsertTranslationKey = api.translationKeys.upsertKey.useMutation({
    onSuccess: () => {
      utils.translationKeys.getAllByPageId.invalidate()
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

  const translateSome = api.translations.translateSome.useMutation()

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

  useHotkeys('meta+k', () => handleAddRow())

  const handleAddRow = useCallback(() => {
    handleUpsertTranslationKey({
      key: `NEW_KEY_${Date.now()}`,
      pageId: page?.id ?? ''
    })
  }, [page?.id, handleUpsertTranslationKey])

  const handleRemoveRow = useCallback(
    (translationKeyId: string) => {
      deleteTranslationKey.mutate({
        id: translationKeyId
      })
    },
    [deleteTranslationKey]
  )

  const handleTranslateAll = useCallback(
    (translationKeyIds: string[]) => {
      translateSome.mutate({
        pageId: page?.id ?? '',
        translationKeyIds
      })
    },
    [translateSome, page?.id]
  )

  const handleTranslateRow = useCallback((translationKeyId: string) => {
    console.log('TODO: translate row', translationKeyId)
  }, [])

  if (isLoadingTranslationKeys || isLoadingLanguages || isLoadingTranslations) {
    return null
  }

  return (
    <div className="px-4">
      <TranslationsTable
        data={translationKeys}
        languages={languages}
        normalizedTranslations={normalizedTranslations}
        onUpdateCell={handleUpdateCell}
        onAddRow={handleAddRow}
        onRemoveRow={handleRemoveRow}
        onTranslateAll={handleTranslateAll}
        onTranslateRow={handleTranslateRow}
      />
    </div>
  )
}
