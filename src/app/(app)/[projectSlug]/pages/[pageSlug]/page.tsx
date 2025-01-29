'use client'
import { TranslationsTable } from '~/components/translations-table'
import { useSelectedPage } from '~/hooks/use-selected-page'
import { api } from '~/trpc/react'

export default function PageDetail() {
  const page = useSelectedPage()
  const { data } = api.translations.getAllByPageId.useQuery(
    {
      pageId: page?.id ?? ''
    },
    { enabled: !!page?.id }
  )

  const translations = [
    ...(data ?? []),
    {
      id: 'new',
      key: '',
      description: '',
      language: '',
      value: ''
    }
  ]

  return (
    <div className="px-4">
      <TranslationsTable translations={translations} />
    </div>
  )
}
