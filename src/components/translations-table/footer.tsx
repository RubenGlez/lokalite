import { TranslationsTableRow } from '~/hooks/use-translations'
import { Button } from '../ui/button'
import { RowModel } from '@tanstack/react-table'

interface FooterProps {
  getFilteredSelectedRowModel: () => RowModel<TranslationsTableRow>
  getFilteredRowModel: () => RowModel<TranslationsTableRow>
  getCanPreviousPage: () => boolean
  getCanNextPage: () => boolean
  previousPage: () => void
  nextPage: () => void
}

export function Footer({
  getFilteredSelectedRowModel,
  getFilteredRowModel,
  getCanPreviousPage,
  getCanNextPage,
  previousPage,
  nextPage
}: FooterProps) {
  return (
    <div className="flex items-center justify-end space-x-2 py-4">
      <div className="flex-1 text-sm text-muted-foreground">
        {getFilteredSelectedRowModel().rows.length} of{' '}
        {getFilteredRowModel().rows.length} row(s) selected.
      </div>
      <div className="space-x-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => previousPage()}
          disabled={!getCanPreviousPage()}
        >
          Previous
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => nextPage()}
          disabled={!getCanNextPage()}
        >
          Next
        </Button>
      </div>
    </div>
  )
}
