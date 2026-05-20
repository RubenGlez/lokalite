'use client'

import {
  ColumnFiltersState,
  PaginationState,
  RowSelectionState,
  SortingState,
  VisibilityState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable
} from '@tanstack/react-table'

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from '~/components/ui/table'
import { getColumns, TranslationsTableMeta } from './columns'
import { Language } from '~/server/db/schema'
import { useSkipper } from '../../hooks/use-skipper'
import { useMemo, useState } from 'react'
import { RightActions } from './right-actions'
import { LeftActions } from './left-actions'
import { Footer } from './footer'
import { TranslationsTableRow } from '~/hooks/use-translations'

interface TranslationsTableProps {
  data: TranslationsTableRow[] | undefined
  onEdit: (translationKeyIds: string[]) => void
  onDelete: (translationKeyIds: string[]) => void
  onTranslate: (translationKeyIds: string[]) => void
  isTranslating: boolean
  isDeleting: boolean
  languages: Language[]
}

export function TranslationsTable({
  data = [],
  onEdit,
  onDelete,
  onTranslate,
  isTranslating,
  isDeleting,
  languages
}: TranslationsTableProps) {
  const [autoResetPageIndex, skipAutoResetPageIndex] = useSkipper()

  const [sorting, setSorting] = useState<SortingState>([])
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])
  const [columnVisibility, setColumnVisibility] = useState<VisibilityState>({})
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({})
  const [pagination, setPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize: 10
  })

  const columns = useMemo(() => getColumns(languages), [languages])

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
    onPaginationChange: setPagination,
    state: {
      sorting,
      columnFilters,
      columnVisibility,
      rowSelection,
      pagination
    },
    autoResetPageIndex,
    meta: {
      onEdit: (translationKeyIds) => {
        skipAutoResetPageIndex()
        onEdit(translationKeyIds)
      },
      onDelete: (translationKeyIds) => {
        skipAutoResetPageIndex()
        onDelete(translationKeyIds)
      },
      onTranslate: (translationKeyIds) => {
        skipAutoResetPageIndex()
        onTranslate(translationKeyIds)
      }
    } satisfies TranslationsTableMeta
  })

  const meta = table.options.meta as TranslationsTableMeta

  return (
    <div className="w-full h-full flex flex-col">
      <div className="flex items-center justify-between py-4">
        <LeftActions
          onDelete={meta.onDelete}
          isTranslating={isTranslating}
          isDeleting={isDeleting}
          onTranslate={meta.onTranslate}
          getFilteredSelectedRowModel={table.getFilteredSelectedRowModel}
          getColumn={table.getColumn}
          onEdit={meta.onEdit}
        />
        <RightActions getAllColumns={table.getAllColumns} />
      </div>

      <div className="rounded-md border flex-1 min-h-0 overflow-y-auto">
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

      <Footer
        getFilteredSelectedRowModel={table.getFilteredSelectedRowModel}
        getFilteredRowModel={table.getFilteredRowModel}
        getCanPreviousPage={table.getCanPreviousPage}
        getCanNextPage={table.getCanNextPage}
        previousPage={table.previousPage}
        nextPage={table.nextPage}
      />
    </div>
  )
}
