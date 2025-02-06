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
import { Language, TranslationKey } from '~/server/db/schema'
import { useSkipper } from './use-skipper'
import { useMemo, useState } from 'react'
import { RightActions } from './right-actions'
import { LeftActions } from './left-actions'
import { Footer } from './footer'

interface TranslationsTableProps {
  data: TranslationKey[] | undefined
  languages: Language[] | undefined
  normalizedTranslations: Record<string, string>
  onUpdateCell: (
    translationId: string | null,
    columnId: string,
    value: string
  ) => void
  onAddRow: (numberOfRows: number) => void
  onDelete: (translationKeyIds: string[]) => void
  onTranslate: (translations: string[]) => void
  defaultLanguageId: string
  isTranslating: boolean
  isDeleting: boolean
}

export function TranslationsTable({
  data = [],
  languages = [],
  normalizedTranslations,
  onUpdateCell,
  onAddRow,
  onDelete,
  onTranslate,
  defaultLanguageId,
  isTranslating,
  isDeleting
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
      updateCell: (translationId, columnId, value) => {
        skipAutoResetPageIndex()
        onUpdateCell(translationId, columnId, value)
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

  return (
    <div className="w-full flex flex-col">
      <div className="flex items-center justify-between py-4">
        <LeftActions
          skipAutoResetPageIndex={skipAutoResetPageIndex}
          onAddRow={onAddRow}
          isTranslating={isTranslating}
          isDeleting={isDeleting}
          onTranslate={onTranslate}
          getFilteredSelectedRowModel={table.getFilteredSelectedRowModel}
        />
        <RightActions
          getColumn={table.getColumn}
          getAllColumns={table.getAllColumns}
        />
      </div>

      <div className="rounded-md border flex flex-col max-h-[calc(100svh-theme(spacing.52))] overflow-hidden">
        <Table>
          <TableHeader
            className="sticky top-0 z-10 bg-background"
            style={{
              boxShadow: '0px 1px 0px hsl(var(--border))'
            }}
          >
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
