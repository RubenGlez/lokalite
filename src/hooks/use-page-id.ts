import { useParams } from 'next/navigation'

export function usePageId() {
  const params = useParams()
  return params.pageId as string
}
