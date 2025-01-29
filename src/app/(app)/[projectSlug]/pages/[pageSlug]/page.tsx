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
      id: null,
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
/**
 * columns:
 * - keys
 * - language 1
 * - language 2
 * - language 3
 * - language 4
 * - language 5
 * - language 6
 * - language 7
 * - language 8
 * - language 9
 * - language 10
 */
