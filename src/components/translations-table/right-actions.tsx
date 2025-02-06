import { ChevronDown } from 'lucide-react'
import {
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger
} from '~/components/ui/dropdown-menu'

import { DropdownMenu } from '~/components/ui/dropdown-menu'
import { Button } from '~/components/ui/button'
import { Input } from '~/components/ui/input'
import { Column } from '@tanstack/react-table'
import { TranslationKey } from '~/server/db/schema'

interface RightActionsProps {
  getColumn: (columnId: string) => Column<TranslationKey, unknown> | undefined
  getAllColumns: () => Column<TranslationKey, unknown>[]
}

export function RightActions({ getColumn, getAllColumns }: RightActionsProps) {
  return (
    <div className="flex items-center space-x-2">
      <Input
        placeholder="Filter by key..."
        value={(getColumn('key')?.getFilterValue() as string) ?? ''}
        onChange={(event) =>
          getColumn('key')?.setFilterValue(event.target.value)
        }
        className="max-w-sm"
      />
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" className="ml-auto">
            Columns <ChevronDown />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {getAllColumns()
            .filter((column) => column.getCanHide())
            .map((column) => {
              return (
                <DropdownMenuCheckboxItem
                  key={column.id}
                  className="capitalize"
                  checked={column.getIsVisible()}
                  onCheckedChange={(value) => column.toggleVisibility(!!value)}
                >
                  {column.id}
                </DropdownMenuCheckboxItem>
              )
            })}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}
