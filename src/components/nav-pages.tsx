'use client'

import { Plus, FileIcon } from 'lucide-react'

import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem
} from '~/components/ui/sidebar'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { api } from '~/trpc/react'
import { PageCreator } from './page-creator'

export function NavPages() {
  const project = useSelectedProject()
  const { data: pages } = api.pages.getByProject.useQuery(
    {
      projectId: project?.id ?? ''
    },
    { enabled: !!project?.id }
  )

  return (
    <SidebarGroup className="group-data-[collapsible=icon]:hidden">
      <SidebarGroupLabel>Pages</SidebarGroupLabel>
      <SidebarMenu>
        {pages?.map((page) => (
          <SidebarMenuItem key={page.id}>
            <SidebarMenuButton asChild>
              <a href={`/${page.slug}`}>
                <FileIcon />
                <span>{page.name}</span>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        ))}

        {project?.id && (
          <PageCreator projectId={project?.id}>
            <SidebarMenuItem>
              <SidebarMenuButton asChild className="cursor-pointer">
                <span>
                  <Plus />
                  <span>Add Page</span>
                </span>
              </SidebarMenuButton>
            </SidebarMenuItem>
          </PageCreator>
        )}
      </SidebarMenu>
    </SidebarGroup>
  )
}
