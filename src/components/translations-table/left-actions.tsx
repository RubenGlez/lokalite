import { Languages, LoaderIcon, PlusCircle, Trash } from 'lucide-react'
import { Button } from '~/components/ui/button'
import { Column, RowModel } from '@tanstack/react-table'
import { TranslationKey } from '~/server/db/schema'
import { Input } from '../ui/input'
import { TranslationCreator } from '../translation-creator'

interface LeftActionsProps {
  isTranslating: boolean
  isDeleting: boolean
  onTranslate: (translationKeyIds: string[]) => void
  onDelete: (translationKeyIds: string[]) => void
  getFilteredSelectedRowModel: () => RowModel<TranslationKey>
  getColumn: (columnId: string) => Column<TranslationKey, unknown> | undefined
  onCreated: () => void
}

export function LeftActions({
  onTranslate,
  isTranslating,
  onDelete,
  isDeleting,
  getFilteredSelectedRowModel,
  getColumn,
  onCreated
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
        <TranslationCreator onCreated={onCreated}>
          <Button size="sm">
            <PlusCircle /> New
          </Button>
        </TranslationCreator>
      </div>

      {getFilteredSelectedRowModel().rows.length > 0 && (
        <>
          <div className="border-r h-4 w-0" />
          <Button
            variant="secondary"
            size="sm"
            disabled={isDeleting}
            onClick={() => {
              onDelete(
                getFilteredSelectedRowModel().rows.map((row) => row.original.id)
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
          <Button
            size="sm"
            variant="secondary"
            disabled={isTranslating}
            onClick={() => {
              onTranslate(
                getFilteredSelectedRowModel().rows.map((row) => row.original.id)
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
        </>
      )}
    </div>
  )
}
