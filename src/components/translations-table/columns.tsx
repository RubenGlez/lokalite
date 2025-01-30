import { Checkbox } from '@radix-ui/react-checkbox'
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuItem
} from '@radix-ui/react-dropdown-menu'
import { CellContext, ColumnDef } from '@tanstack/react-table'
import { ArrowUpDown, MoreHorizontal } from 'lucide-react'
import { Language, TranslationKey } from '~/server/db/types'
import { Button } from '../ui/button'
import { MemoizedEditableCell } from './editable-cell'

const basicColumns: ColumnDef<TranslationKey>[] = [
  {
    id: 'select',
    header: ({ table }) => (
      <Checkbox
        checked={
          table.getIsAllPageRowsSelected() ||
          (table.getIsSomePageRowsSelected() && 'indeterminate')
        }
        onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
        aria-label="Select all"
      />
    ),
    cell: ({ row }) => (
      <Checkbox
        checked={row.getIsSelected()}
        onCheckedChange={(value) => row.toggleSelected(!!value)}
        aria-label="Select row"
      />
    ),
    enableSorting: false,
    enableHiding: false
  },
  {
    accessorKey: 'key',
    header: ({ column }) => {
      return (
        <Button
          variant="ghost"
          onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}
        >
          Key
          <ArrowUpDown />
        </Button>
      )
    },
    cell: (props: CellContext<TranslationKey, unknown>) => {
      const onUpdateCell = (value: string) => {
        props.table.options.meta?.updateCell(
          props.row.original.id,
          props.column.id,
          value
        )
      }

      return (
        <MemoizedEditableCell
          onUpdateCell={onUpdateCell}
          initialValue={props.getValue() as string}
        />
      )
    }
  }
]

const actionColum: ColumnDef<TranslationKey> = {
  id: 'actions',
  enableHiding: false,
  cell: () => {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="h-8 w-8 p-0">
            <span className="sr-only">Open menu</span>
            <MoreHorizontal />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>Actions</DropdownMenuLabel>
          <DropdownMenuItem>Translate</DropdownMenuItem>
          <DropdownMenuItem>Delete</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )
  }
}

export const getColumns = (languages: Language[]) => {
  const languageColumns = languages.map((language) => {
    return {
      accessorKey: language.code,
      header: ({ column }) => {
        return (
          <Button
            variant="ghost"
            onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}
          >
            {language.name}
            <ArrowUpDown />
          </Button>
        )
      },
      cell: (props) => {
        const onUpdateCell = (value: string) => {
          console.log(
            'updating language column',
            props.row.original.id,
            props.column.id,
            value
          )
        }

        return (
          <MemoizedEditableCell onUpdateCell={onUpdateCell} initialValue={''} />
        )
      }
    } satisfies ColumnDef<TranslationKey>
  })

  return [...basicColumns, ...languageColumns, actionColum]
}
