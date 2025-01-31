import { useParams } from 'next/navigation'

export function usePageSlug() {
  const params = useParams()
  return params.pageSlug as string
}
