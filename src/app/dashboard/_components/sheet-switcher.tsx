'use client'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuCheckboxItem
} from '@/components/ui/dropdown-menu'
import { ChevronDown } from 'lucide-react'

const options = [
  {
    value: 'webapp',
    label: 'Web App'
  },
  {
    value: 'iosapp',
    label: 'iOS App'
  },
  {
    value: 'androidapp',
    label: 'Android App'
  },
  {
    value: 'landing',
    label: 'Landing'
  }
]

export default function SheetSwitcher() {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" className="ml-auto">
          Sheets <ChevronDown className="ml-2 h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {options.map(({ value, label }) => {
          return (
            <DropdownMenuCheckboxItem
              key={value}
              className="capitalize"
              checked={value === 'webapp'}
              onCheckedChange={() => {}}
            >
              {label}
            </DropdownMenuCheckboxItem>
          )
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
