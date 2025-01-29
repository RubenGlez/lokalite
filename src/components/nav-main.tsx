'use client'

import {
  ChevronRight,
  LayoutDashboard,
  Settings2,
  SquareTerminal
} from 'lucide-react'
import { usePathname } from 'next/navigation'

import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem
} from '~/components/ui/sidebar'

import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger
} from './ui/collapsible'
import { cn } from '~/lib/utils'

const items = [
  {
    title: 'Pages',
    url: '#',
    icon: SquareTerminal,
    isActive: true,
    items: [
      {
        title: 'Page 1',
        url: '#'
      },
      {
        title: 'Page 2',
        url: '#'
      },
      {
        title: 'Page 3',
        url: '#'
      }
    ]
  }
]

export function NavMain() {
  const pathname = usePathname()

  return (
    <SidebarGroup>
      <SidebarGroupLabel>Project</SidebarGroupLabel>
      <SidebarMenu>
        <SidebarMenuItem key={'dashboard-item'}>
          <SidebarMenuButton
            asChild
            className={cn(
              pathname === '/dashboard' &&
                'bg-sidebar-accent text-sidebar-accent-foreground rounded-md'
            )}
          >
            <a href={'#'}>
              <LayoutDashboard />
              <span>Dashboard</span>
            </a>
          </SidebarMenuButton>
        </SidebarMenuItem>

        {items.map((item) => (
          <Collapsible
            key={item.title}
            asChild
            defaultOpen={item.isActive}
            className="group/collapsible"
          >
            <SidebarMenuItem>
              <CollapsibleTrigger asChild>
                <SidebarMenuButton tooltip={item.title}>
                  {item.icon && <item.icon />}
                  <span>{item.title}</span>
                  <ChevronRight className="ml-auto transition-transform duration-200 group-data-[state=open]/collapsible:rotate-90" />
                </SidebarMenuButton>
              </CollapsibleTrigger>
              <CollapsibleContent>
                <SidebarMenuSub>
                  {item.items?.map((subItem) => (
                    <SidebarMenuSubItem key={subItem.title}>
                      <SidebarMenuSubButton asChild>
                        <a href={subItem.url}>
                          <span>{subItem.title}</span>
                        </a>
                      </SidebarMenuSubButton>
                    </SidebarMenuSubItem>
                  ))}
                </SidebarMenuSub>
              </CollapsibleContent>
            </SidebarMenuItem>
          </Collapsible>
        ))}

        <SidebarMenuItem key={'settings-item'}>
          <SidebarMenuButton
            asChild
            className={cn(
              pathname === '/settings' &&
                'bg-sidebar-accent text-sidebar-accent-foreground rounded-md'
            )}
          >
            <a href={'#'}>
              <Settings2 />
              <span>Settings</span>
            </a>
          </SidebarMenuButton>
        </SidebarMenuItem>
      </SidebarMenu>
    </SidebarGroup>
  )
}
