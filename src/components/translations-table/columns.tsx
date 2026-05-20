import { Checkbox } from '~/components/ui/checkbox'
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem
} from '~/components/ui/dropdown-menu'
import { ColumnDef } from '@tanstack/react-table'
import {
  ArrowUpDown,
  CircleDashed,
  CircleDot,
  CircleDotDashed,
  Languages,
  MoreHorizontal,
  Pen,
  Trash2
} from 'lucide-react'
import { Language } from '~/server/db/schema'
import { Button } from '~/components/ui/button'
import { TranslationsTableRow } from '~/hooks/use-translations'
import {
  Tooltip,
  TooltipTrigger,
  TooltipContent
} from '~/components/ui/tooltip'

export interface TranslationsTableMeta {
  onEdit: (translationKeyIds: string[]) => void
  onDelete: (translationKeyIds: string[]) => void
  onTranslate: (translationKeyIds: string[]) => void
}

const basicColumns: ColumnDef<TranslationsTableRow>[] = [
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
    id: 'key',
    accessorKey: 'keyValue',
    header: ({ column }) => {
      return (
        <Button
          size="sm"
          variant="ghost"
          onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}
        >
          Key
          <ArrowUpDown />
        </Button>
      )
    },
    cell: (props) => (
      <span className="pl-3 truncate">{props.getValue() as string}</span>
    )
  }
]

const actionColum: ColumnDef<TranslationsTableRow> = {
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
              meta.onEdit([row.original.keyId])
            }}
          >
            <Pen />
            Edit
          </DropdownMenuItem>
          <DropdownMenuItem
            onClick={() => {
              const meta = table.options.meta as TranslationsTableMeta
              meta.onTranslate([row.original.keyId])
            }}
          >
            <Languages />
            Translate
          </DropdownMenuItem>
          <DropdownMenuItem
            onClick={() => {
              const meta = table.options.meta as TranslationsTableMeta
              meta.onDelete([row.original.keyId])
            }}
          >
            <Trash2 />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )
  }
}

export const getColumns = (languages: Language[]) => {
  const languageColumns = languages
    .sort((a, b) => (a.isSource ? -1 : b.isSource ? 1 : 0))
    .map((language) => {
      return {
        accessorKey: language.code,
        accessorFn: (row) => row.translations[language.code] ?? '',
        header: ({ column }) => {
          return (
            <Button
              size="sm"
              variant="ghost"
              onClick={() =>
                column.toggleSorting(column.getIsSorted() === 'asc')
              }
            >
              {language.isSource ? `${language.name} (Source)` : language.name}
              <ArrowUpDown />
            </Button>
          )
        },
        cell: (props) => {
          const value = props.getValue() as string
          const parts = value.split(/(\{\{.*?\}\})/g)

          return (
            <span className="pl-3 truncate">
              {parts.map((part, index) =>
                part.match(/^\{\{.*?\}\}$/) ? (
                  <span key={index} className="text-muted-foreground">
                    {part}
                  </span>
                ) : (
                  <span key={index}>{part}</span>
                )
              )}
            </span>
          )
        }
      } satisfies ColumnDef<TranslationsTableRow>
    })

  const statusColum: ColumnDef<TranslationsTableRow> = {
    id: 'status',
    header: ({ column }) => {
      return (
        <Button
          size="sm"
          variant="ghost"
          onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}
        >
          Status
          <ArrowUpDown />
        </Button>
      )
    },
    cell: ({ row }) => {
      const totalLanguages = languages.length - 1
      const languagesFilled =
        languages.filter((language) => row.getValue(language.code) !== '')
          .length - 1

      return (
        <Tooltip>
          <TooltipTrigger>
            <div className="flex items-center pl-3">
              {languagesFilled === totalLanguages ? (
                <CircleDot className="w-4 h-4 text-green-500" />
              ) : languagesFilled > 0 ? (
                <CircleDotDashed className="w-4 h-4 text-orange-500" />
              ) : (
                <CircleDashed className="w-4 h-4 text-neutral-500" />
              )}
            </div>
          </TooltipTrigger>
          <TooltipContent>
            {`${languagesFilled} of ${totalLanguages} translations`}
          </TooltipContent>
        </Tooltip>
      )
    }
  }

  return [...basicColumns, statusColum, ...languageColumns, actionColum]
}
