import Link from 'next/link'
import { notFound } from 'next/navigation'
import { Card, CardHeader, CardTitle } from '~/components/ui/card'
import { api } from '~/trpc/server'

interface PagesManagementProps {
  params: { projectSlug: string }
}

export default async function PagesManagement({
  params
}: PagesManagementProps) {
  const projects = await api.projects.getBySlug({
    slug: params.projectSlug
  })

  if (!projects) {
    return notFound()
  }

  const pages = await api.pages.getByProject({
    projectId: projects.id
  })

  return (
    <div className="grid grid-cols-4 p-4">
      {pages.map((page) => (
        <Link key={page.id} href={`/${params.projectSlug}/pages/${page.slug}`}>
          <Card>
            <CardHeader>
              <CardTitle>{page.name}</CardTitle>
            </CardHeader>
          </Card>
        </Link>
      ))}
    </div>
  )
}
