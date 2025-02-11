import { Languages, LoaderIcon, Pen, PlusCircle, Trash } from 'lucide-react'
import { Button } from '~/components/ui/button'
import { Column, RowModel } from '@tanstack/react-table'
import { Input } from '../ui/input'
import { TranslationCreator } from '../translation-creator'
import { TranslationsTableRow } from '~/hooks/use-translations'

interface LeftActionsProps {
  isTranslating: boolean
  isDeleting: boolean
  onEdit: (translationKeyIds: string[]) => void
  onTranslate: (translationKeyIds: string[]) => void
  onDelete: (translationKeyIds: string[]) => void
  getFilteredSelectedRowModel: () => RowModel<TranslationsTableRow>
  getColumn: (
    columnId: string
  ) => Column<TranslationsTableRow, unknown> | undefined
}

export function LeftActions({
  onTranslate,
  isTranslating,
  onDelete,
  isDeleting,
  getFilteredSelectedRowModel,
  getColumn,
  onEdit
}: LeftActionsProps) {
  return (
    <div className="flex items-center space-x-2">
      <Input
        placeholder="Filter by key..."
        value={(getColumn('key')?.getFilterValue() as string) ?? ''}
        onChange={(event) =>
          getColumn('key')?.setFilterValue(event.target.value)
        }
        className="h-8"
      />

      <div className="flex items-center">
        <TranslationCreator>
          <Button size="sm">
            <PlusCircle /> New
          </Button>
        </TranslationCreator>
      </div>

      {getFilteredSelectedRowModel().rows.length > 0 && (
        <>
          <div className="border-r h-4 w-0" />
          <Button
            size="sm"
            variant="secondary"
            disabled={false}
            onClick={() => {
              onEdit(
                getFilteredSelectedRowModel().rows.map(
                  (row) => row.original.keyId
                )
              )
            }}
          >
            <Pen />
            <span>Edit</span>
          </Button>
          <Button
            size="sm"
            variant="secondary"
            disabled={isTranslating}
            onClick={() => {
              onTranslate(
                getFilteredSelectedRowModel().rows.map(
                  (row) => row.original.keyId
                )
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
          <Button
            variant="secondary"
            size="sm"
            disabled={isDeleting}
            onClick={() => {
              onDelete(
                getFilteredSelectedRowModel().rows.map(
                  (row) => row.original.keyId
                )
              )
            }}
          >
            {isDeleting ? (
              <>
                <LoaderIcon className="animate-spin" />
                <span>Deleting...</span>
              </>
            ) : (
              <>
                <Trash />
                <span>Delete</span>
              </>
            )}
          </Button>
        </>
      )}
    </div>
  )
}
