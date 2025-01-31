import { api } from '~/trpc/react'
import { usePageSlug } from './use-page-slug'

export function useSelectedPage() {
  const pageSlug = usePageSlug()
  const { data: pages } = api.pages.getBySlug.useQuery(
    { slug: pageSlug },
    { enabled: !!pageSlug }
  )

  return pages
}
