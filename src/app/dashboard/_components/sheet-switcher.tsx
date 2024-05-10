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
    label: 'Sheets',
    sheets: [
      {
        label: 'About Page',
        value: '1'
      },
      {
        label: 'Store page',
        value: '2'
      },
      {
        label: 'Products page',
        value: '3'
      }
    ]
  }
]

type Sheet = (typeof groups)[number]['sheets'][number]

type PopoverTriggerProps = React.ComponentPropsWithoutRef<typeof PopoverTrigger>

interface SheetSwitcherProps extends PopoverTriggerProps {}

export default function SheetSwitcher({ className }: SheetSwitcherProps) {
  const [open, setOpen] = React.useState(false)
  const [showNewSheetDialog, setShowNewSheetDialog] = React.useState(false)
  const [selectedSheet, setSelectedSheet] = React.useState<Sheet>(
    groups[0].sheets[0]
  )

  return (
    <Dialog open={showNewSheetDialog} onOpenChange={setShowNewSheetDialog}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            role="combobox"
            aria-expanded={open}
            aria-label="Select a sheet"
            className={cn('w-[180px]', className)}
          >
            {selectedSheet.label}
            <ChevronsUpDown className="ml-auto h-4 w-4 shrink-0 opacity-50" />
          </Button>
        </PopoverTrigger>

        <PopoverContent className="w-[200px] p-0" align="start">
          <Command>
            <CommandList>
              <CommandInput placeholder="Search sheet..." />
              <CommandEmpty>No sheet found.</CommandEmpty>
              {groups.map((group) => (
                <CommandGroup key={group.label} heading={group.label}>
                  {group.sheets.map((sheet) => (
                    <CommandItem
                      key={sheet.value}
                      onSelect={() => {
                        setSelectedSheet(sheet)
                        setOpen(false)
                      }}
                      className="text-sm"
                    >
                      {sheet.label}
                      <CheckIcon
                        className={cn(
                          'ml-auto h-4 w-4',
                          selectedSheet.value === sheet.value
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
                      setShowNewSheetDialog(true)
                    }}
                  >
                    <PlusCircleIcon className="mr-2 h-4 w-4" />
                    Create Sheet
                  </CommandItem>
                </DialogTrigger>
              </CommandGroup>
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>

      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create sheet</DialogTitle>
          <DialogDescription>Add a new sheet this project.</DialogDescription>
        </DialogHeader>
        <div>
          <div className="space-y-4 py-2 pb-4">
            <div className="space-y-2">
              <Label htmlFor="name">Sheet name</Label>
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
            onClick={() => setShowNewSheetDialog(false)}
          >
            Cancel
          </Button>
          <Button type="submit">Continue</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
