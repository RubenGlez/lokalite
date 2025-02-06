import {
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel
} from '~/components/ui/dropdown-menu'

import { DropdownMenuTrigger } from '~/components/ui/dropdown-menu'

import {
  ChevronDown,
  Languages,
  LoaderIcon,
  PlusCircle,
  Trash
} from 'lucide-react'
import { Button } from '~/components/ui/button'
import { DropdownMenu } from '~/components/ui/dropdown-menu'
import { RowModel } from '@tanstack/react-table'
import { TranslationKey } from '~/server/db/schema'

interface LeftActionsProps {
  skipAutoResetPageIndex: () => void
  onAddRow: (numberOfRows: number) => void
  isTranslating: boolean
  isDeleting: boolean
  onTranslate: (translationKeyIds: string[]) => void
  getFilteredSelectedRowModel: () => RowModel<TranslationKey>
}

export function LeftActions({
  skipAutoResetPageIndex,
  onAddRow,
  isTranslating,
  isDeleting,
  onTranslate,
  getFilteredSelectedRowModel
}: LeftActionsProps) {
  return (
    <div className="flex items-center space-x-2">
      <div className="flex items-center">
        <Button
          variant="outline"
          className="rounded-r-none"
          onClick={() => {
            skipAutoResetPageIndex()
            onAddRow(1)
          }}
        >
          <PlusCircle /> Add
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="outline"
              className="px-2 rounded-l-none border-l-transparent"
            >
              <ChevronDown />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel>Actions</DropdownMenuLabel>
            <DropdownMenuGroup>
              <DropdownMenuItem
                onClick={() => {
                  skipAutoResetPageIndex()
                  onAddRow(5)
                }}
              >
                Add 5 keys
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => {
                  skipAutoResetPageIndex()
                  onAddRow(10)
                }}
              >
                Add 10 keys
              </DropdownMenuItem>
            </DropdownMenuGroup>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {getFilteredSelectedRowModel().rows.length > 0 && (
        <>
          <Button
            disabled={isTranslating}
            onClick={() => {
              skipAutoResetPageIndex()
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
          <Button
            variant="destructive"
            disabled={isDeleting}
            onClick={() => {
              skipAutoResetPageIndex()
              // todo
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
