import { ChevronRight } from 'lucide-react'
import Link from 'next/link'
import { ProjectCreator } from '~/components/project-creator'
import { Button } from '~/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle
} from '~/components/ui/card'
import { api } from '~/trpc/server'

export default async function Home() {
  const projects = await api.projects.getAll()

  return (
    <div className="h-svh w-full flex justify-center items-center">
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Welcome to Lokalite 👋</CardTitle>
          <CardDescription>
            Select one of your projects below or create a new one ✨
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col gap-2">
            {projects.map((project) => (
              <Link
                key={project.id}
                href={project.slug}
                className="flex justify-between items-center rounded-md p-2 hover:bg-foreground/10 gap-2 transition-colors"
              >
                <h3>{project.name}</h3>
                <ChevronRight />
              </Link>
            ))}
          </div>
        </CardContent>
        <CardFooter className="flex justify-end">
          <ProjectCreator>
            <Button>Create project</Button>
          </ProjectCreator>
        </CardFooter>
      </Card>
    </div>
  )
}
