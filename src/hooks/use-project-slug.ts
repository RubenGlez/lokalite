import { useParams } from 'next/navigation'

export function useProjectSlug() {
  const params = useParams()
  return params.projectSlug as string
}
