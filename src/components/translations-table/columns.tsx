import { Checkbox } from '~/components/ui/checkbox'
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem
} from '~/components/ui/dropdown-menu'
import { CellContext, ColumnDef } from '@tanstack/react-table'
import { ArrowUpDown, MoreHorizontal } from 'lucide-react'
import { Language, TranslationKey } from '~/server/db/schema'
import { Button } from '~/components/ui/button'
import { MemoizedEditableCell } from './editable-cell'

export interface TranslationsTableMeta {
  updateCell: (
    translationId: string | null,
    columnId: string,
    value: string
  ) => void
  onRemoveRow: (translationKeyId: string) => void
  onTranslateRow: (translationKeyId: string) => void
}

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
          className="-ml-1"
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
        const meta = props.table.options.meta as TranslationsTableMeta

        meta.updateCell(props.row.original.id, props.column.id, value)
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
  cell: ({ table, row }) => {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="h-8 w-8 p-0">
            <span className="sr-only">Open menu</span>
            <MoreHorizontal />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem
            onClick={() => {
              const meta = table.options.meta as TranslationsTableMeta
              meta.onTranslateRow(row.original.id)
            }}
          >
            Translate
          </DropdownMenuItem>
          <DropdownMenuItem
            onClick={() => {
              const meta = table.options.meta as TranslationsTableMeta
              meta.onRemoveRow(row.original.id)
            }}
          >
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )
  }
}

interface GetColumnsProps {
  languages: Language[]
  normalizedTranslations: Record<string, string>
  defaultLanguageId: string
}

export const getColumns = ({
  languages,
  normalizedTranslations,
  defaultLanguageId
}: GetColumnsProps) => {
  const languageColumns = languages
    .sort((a, b) => {
      if (a.id === defaultLanguageId) {
        return -1
      }
      if (b.id === defaultLanguageId) {
        return 1
      }
      return 0
    })
    .map((language) => {
      return {
        accessorKey: language.code,
        accessorFn: (row) =>
          normalizedTranslations[`${row.id}_${language.id}`] ?? '',
        header: ({ column }) => {
          return (
            <Button
              className="-ml-1"
              variant="ghost"
              onClick={() =>
                column.toggleSorting(column.getIsSorted() === 'asc')
              }
            >
              {language.name}
              <ArrowUpDown />
            </Button>
          )
        },
        cell: (props) => {
          const onUpdateCell = (value: string) => {
            const meta = props.table.options.meta as TranslationsTableMeta
            meta.updateCell(props.row.original.id, props.column.id, value)
          }

          // This represents the translationKey.id and language.id
          const translationIndexKey = `${props.row.original.id}_${language.id}`
          const initialValue = normalizedTranslations[translationIndexKey] ?? ''

          return (
            <MemoizedEditableCell
              onUpdateCell={onUpdateCell}
              initialValue={initialValue}
            />
          )
        }
      } satisfies ColumnDef<TranslationKey>
    })

  return [...basicColumns, ...languageColumns, actionColum]
}
