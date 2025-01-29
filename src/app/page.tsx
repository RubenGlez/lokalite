import { ChevronRight } from 'lucide-react'
import Link from 'next/link'
import { ProjectCreator } from '~/components/project-creator'
import { Button } from '~/components/ui/button'
import { api } from '~/trpc/server'

export default async function Home() {
  const projects = await api.projects.getAll()

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Your Projects
          </h1>
          <p className="text-gray-600">
            Select an existing project or create a new one
          </p>
        </div>

        <div className="grid gap-4 mb-12">
          {projects.map((project) => (
            <Link
              key={project.id}
              href={project.slug}
              className="block p-6 bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200 border border-gray-200"
            >
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-medium text-gray-900">
                  {project.name}
                </h3>
                <ChevronRight className="w-5 h-5 text-gray-500" />
              </div>
            </Link>
          ))}
        </div>

        <ProjectCreator>
          <Button>Create Project</Button>
        </ProjectCreator>
      </div>
    </div>
  )
}
