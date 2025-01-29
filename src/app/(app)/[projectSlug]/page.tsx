'use client'
import { BookA, File, Languages } from 'lucide-react'
import Link from 'next/link'
import { LanguagesTable } from '~/components/languages-table'

import { Card, CardHeader, CardTitle, CardContent } from '~/components/ui/card'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { api } from '~/trpc/react'

export default function ProjectOverview() {
  const project = useSelectedProject()
  const { data: languages } = api.languages.getByProject.useQuery(
    {
      projectId: project?.id ?? ''
    },
    {
      enabled: !!project?.id
    }
  )

  const { data: translationKeys } =
    api.translationKeys.getAllByProjectId.useQuery(
      {
        projectId: project?.id ?? ''
      },
      {
        enabled: !!project?.id
      }
    )

  const { data: pages } = api.pages.getByProject.useQuery(
    {
      projectId: project?.id ?? ''
    },
    {
      enabled: !!project?.id
    }
  )

  if (!project) {
    return <div>No project selected</div>
  }

  return (
    <div className="flex flex-1 flex-col gap-4 p-4 pt-0">
      <div className="grid auto-rows-min gap-4 md:grid-cols-3">
        <Link href={`/${project.slug}/pages`}>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Pages</CardTitle>
              <File className="h-4 w-4" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{pages?.length ?? 0}</div>
              <p className="text-xs text-muted-foreground">View details</p>
            </CardContent>
          </Card>
        </Link>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Languages</CardTitle>
            <Languages className="h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{languages?.length ?? 0}</div>
            <p className="text-xs text-muted-foreground">in this project</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Translations</CardTitle>
            <BookA className="h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {translationKeys?.length ?? 0}
            </div>
            <p className="text-xs text-muted-foreground">in all pages</p>
          </CardContent>
        </Card>
      </div>

      <LanguagesTable languages={languages ?? []} />
    </div>
  )
}
