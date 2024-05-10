'use client'

import * as React from 'react'
import { ChevronsUpDown, CheckIcon, PlusCircleIcon } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator
} from '@/components/ui/command'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Popover,
  PopoverContent,
  PopoverTrigger
} from '@/components/ui/popover'
import { Textarea } from '@/components/ui/textarea'

const groups = [
  {
    label: 'Projects',
    projects: [
      {
        label: 'Acme Inc.',
        value: 'acme-inc'
      },
      {
        label: 'Monsters Inc.',
        value: 'monsters'
      }
    ]
  }
]

type Project = (typeof groups)[number]['projects'][number]

type PopoverTriggerProps = React.ComponentPropsWithoutRef<typeof PopoverTrigger>

interface ProjectSwitcherProps extends PopoverTriggerProps {}

export default function ProjectSwitcher({ className }: ProjectSwitcherProps) {
  const [open, setOpen] = React.useState(false)
  const [showNewProjectDialog, setShowNewProjectDialog] = React.useState(false)
  const [selectedProject, setSelectedProject] = React.useState<Project>(
    groups[0].projects[0]
  )

  return (
    <Dialog open={showNewProjectDialog} onOpenChange={setShowNewProjectDialog}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            role="combobox"
            aria-expanded={open}
            aria-label="Select a project"
            className={cn('w-[140px]', className)}
          >
            {selectedProject.label}
            <ChevronsUpDown className="ml-auto h-4 w-4 shrink-0 opacity-50" />
          </Button>
        </PopoverTrigger>

        <PopoverContent className="w-[200px] p-0" align="start">
          <Command>
            <CommandList>
              <CommandInput placeholder="Search project..." />
              <CommandEmpty>No project found.</CommandEmpty>
              {groups.map((group) => (
                <CommandGroup key={group.label} heading={group.label}>
                  {group.projects.map((project) => (
                    <CommandItem
                      key={project.value}
                      onSelect={() => {
                        setSelectedProject(project)
                        setOpen(false)
                      }}
                      className="text-sm"
                    >
                      {project.label}
                      <CheckIcon
                        className={cn(
                          'ml-auto h-4 w-4',
                          selectedProject.value === project.value
                            ? 'opacity-100'
                            : 'opacity-0'
                        )}
                      />
                    </CommandItem>
                  ))}
                </CommandGroup>
              ))}
            </CommandList>

            <CommandSeparator />

            <CommandList>
              <CommandGroup>
                <DialogTrigger asChild>
                  <CommandItem
                    onSelect={() => {
                      setOpen(false)
                      setShowNewProjectDialog(true)
                    }}
                  >
                    <PlusCircleIcon className="mr-2 h-4 w-4" />
                    Create Project
                  </CommandItem>
                </DialogTrigger>
              </CommandGroup>
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>

      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create project</DialogTitle>
          <DialogDescription>
            Add a new project to manage the translations.
          </DialogDescription>
        </DialogHeader>
        <div>
          <div className="space-y-4 py-2 pb-4">
            <div className="space-y-2">
              <Label htmlFor="name">Project name</Label>
              <Input id="name" placeholder="Acme Inc." />
            </div>
            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                placeholder="Type your description here."
              />
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => setShowNewProjectDialog(false)}
          >
            Cancel
          </Button>
          <Button type="submit">Continue</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
