'use client'

import {
  ColumnFiltersState,
  SortingState,
  VisibilityState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable
} from '@tanstack/react-table'
import { ChevronDown, Languages, Plus } from 'lucide-react'

import { Button } from '~/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger
} from '~/components/ui/dropdown-menu'
import { Input } from '~/components/ui/input'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from '~/components/ui/table'
import { getColumns, TranslationsTableMeta } from './columns'
import { Language, TranslationKey } from '~/server/db/schema'
import { useSkipper } from './use-skipper'
import { useMemo, useState } from 'react'
import { LoaderIcon } from 'lucide-react'

interface TranslationsTableProps {
  data: TranslationKey[] | undefined
  languages: Language[] | undefined
  normalizedTranslations: Record<string, string>
  onUpdateCell: (
    translationId: string | null,
    columnId: string,
    value: string
  ) => void
  onAddRow: () => void
  onRemoveRow: (translationKeyId: string) => void
  onTranslate: (translations: string[]) => void
  defaultLanguageId: string
  isTranslating: boolean
}

export function TranslationsTable({
  data = [],
  languages = [],
  normalizedTranslations,
  onUpdateCell,
  onAddRow,
  onRemoveRow,
  onTranslate,
  defaultLanguageId,
  isTranslating
}: TranslationsTableProps) {
  const [autoResetPageIndex, skipAutoResetPageIndex] = useSkipper()

  const [sorting, setSorting] = useState<SortingState>([])
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])
  const [columnVisibility, setColumnVisibility] = useState<VisibilityState>({})
  const [rowSelection, setRowSelection] = useState({})

  const columns = useMemo(
    () => getColumns({ languages, normalizedTranslations, defaultLanguageId }),
    [languages, normalizedTranslations, defaultLanguageId]
  )

  const table = useReactTable({
    data,
    columns,
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    onColumnVisibilityChange: setColumnVisibility,
    onRowSelectionChange: setRowSelection,
    state: {
      sorting,
      columnFilters,
      columnVisibility,
      rowSelection
    },
    autoResetPageIndex,
    meta: {
      updateCell: (translationId, columnId, value) => {
        skipAutoResetPageIndex()
        onUpdateCell(translationId, columnId, value)
      },
      onRemoveRow: (translationKeyId) => {
        skipAutoResetPageIndex()
        onRemoveRow(translationKeyId)
      },
      onTranslateRow: (translationKeyId) => {
        skipAutoResetPageIndex()
        onTranslate([translationKeyId])
      }
    } satisfies TranslationsTableMeta
  })

  return (
    <div className="w-full">
      <div className="flex items-center justify-between py-4">
        <div className="flex items-center space-x-2">
          <Button
            variant="outline"
            onClick={() => {
              skipAutoResetPageIndex()
              onAddRow()
            }}
          >
            <Plus /> Add
            <span className="text-xs bg-primary-foreground rounded-sm px-1">
              ⌘K
            </span>
          </Button>
          <Button
            disabled={
              !table.getFilteredSelectedRowModel().rows.length || isTranslating
            }
            onClick={() => {
              skipAutoResetPageIndex()
              onTranslate(
                table
                  .getFilteredSelectedRowModel()
                  .rows.map((row) => row.original.id)
              )
            }}
          >
            {isTranslating ? (
              <>
                <LoaderIcon className="animate-spin" />
                <span>Translating...</span>
              </>
            ) : (
              <>
                <Languages />
                <span>Translate</span>
              </>
            )}
          </Button>
        </div>

        <div className="flex items-center space-x-2">
          <Input
            placeholder="Filter by key..."
            value={(table.getColumn('key')?.getFilterValue() as string) ?? ''}
            onChange={(event) =>
              table.getColumn('key')?.setFilterValue(event.target.value)
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
              {table
                .getAllColumns()
                .filter((column) => column.getCanHide())
                .map((column) => {
                  return (
                    <DropdownMenuCheckboxItem
                      key={column.id}
                      className="capitalize"
                      checked={column.getIsVisible()}
                      onCheckedChange={(value) =>
                        column.toggleVisibility(!!value)
                      }
                    >
                      {column.id}
                    </DropdownMenuCheckboxItem>
                  )
                })}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => {
                  return (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                    </TableHead>
                  )
                })}
              </TableRow>
            ))}
          </TableHeader>

          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow
                  key={row.id}
                  data-state={row.getIsSelected() && 'selected'}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="h-24 text-center"
                >
                  No results.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <div className="flex items-center justify-end space-x-2 py-4">
        <div className="flex-1 text-sm text-muted-foreground">
          {table.getFilteredSelectedRowModel().rows.length} of{' '}
          {table.getFilteredRowModel().rows.length} row(s) selected.
        </div>
        <div className="space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.previousPage()}
            disabled={!table.getCanPreviousPage()}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.nextPage()}
            disabled={!table.getCanNextPage()}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  )
}
