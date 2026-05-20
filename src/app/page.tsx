import { redirect } from 'next/navigation'
import { ProjectCreator } from '~/components/project-creator'
import { Button } from '~/components/ui/button'
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle
} from '~/components/ui/card'
import { api } from '~/trpc/server'

export default async function Home() {
  const projects = await api.projects.getAll()

  if (projects.length > 0) {
    redirect(`/${projects[0]?.slug}`)
  }

  return (
    <div className="h-svh w-full flex justify-center items-center">
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Welcome to Lokalite</CardTitle>
          <CardDescription>Create a project to get started ✨</CardDescription>
        </CardHeader>
        <CardFooter className="flex justify-end">
          <ProjectCreator>
            <Button className="w-full">Create project</Button>
          </ProjectCreator>
        </CardFooter>
      </Card>
    </div>
  )
}
