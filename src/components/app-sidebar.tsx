'use client'

import * as React from 'react'
import { Settings2, SquareTerminal } from 'lucide-react'

import { NavMain } from '~/components/nav-main'
import { NavUser } from '~/components/nav-user'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail
} from '~/components/ui/sidebar'
import { ProjectSwitcher } from './project-switcher'
import { NavPages } from './nav-pages'

// This is sample data.
const data = {
  user: {
    name: 'ruben',
    email: 'ruben@glez.com',
    avatar: 'https://picsum.photos/100/100'
  },
  projects: [
    {
      name: 'Manager v2',
      slug: 'manager-v2'
    },
    {
      name: 'Product v2',
      slug: 'product-v2'
    },
    {
      name: 'iOS App',
      slug: 'ios-app'
    }
  ],
  navMain: [
    {
      title: 'Dashboard',
      url: '/dashboard',
      icon: SquareTerminal,
      isActive: true
    },
    {
      title: 'Settings',
      url: '/settings',
      icon: Settings2
    }
  ],
  pages: [
    {
      name: 'Page 1',
      url: '#'
    },
    {
      name: 'Page 2',
      url: '#'
    },
    {
      name: 'Page 3',
      url: '#'
    }
  ]
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <ProjectSwitcher projects={data.projects} />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={data.navMain} />
        <NavPages pages={data.pages} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={data.user} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
