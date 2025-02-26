import { api } from '~/trpc/react'
import { useProjectSlug } from './use-project-slug'

export function useSelectedProject() {
  const projectSlug = useProjectSlug()
  const { data: projects } = api.projects.getBySlug.useQuery(
    { slug: projectSlug },
    { enabled: !!projectSlug }
  )

  return projects
}
