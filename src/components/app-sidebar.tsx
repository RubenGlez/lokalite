import { NavUser } from '~/components/nav-user'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail
} from '~/components/ui/sidebar'
import { ProjectSwitcher } from './project-switcher'
import { api } from '~/trpc/server'
import { NavPages } from './nav-pages'
import { ComponentProps } from 'react'

export async function AppSidebar({ ...props }: ComponentProps<typeof Sidebar>) {
  const projects = await api.projects.getAll()

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <ProjectSwitcher projects={projects} />
      </SidebarHeader>
      <SidebarContent>
        <NavPages />
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
