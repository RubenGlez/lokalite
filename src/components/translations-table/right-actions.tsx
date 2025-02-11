import { Download, Settings2 } from 'lucide-react'
import {
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from '~/components/ui/dropdown-menu'
import JSZip from 'jszip'

import { DropdownMenu } from '~/components/ui/dropdown-menu'
import { Button } from '~/components/ui/button'
import { Column } from '@tanstack/react-table'
import { TranslationKey } from '~/server/db/schema'
import { useSelectedProject } from '~/hooks/use-selected-project'
import { useSelectedPage } from '~/hooks/use-selected-page'

interface RightActionsProps {
  getAllColumns: () => Column<TranslationKey, unknown>[]
}

async function downloadTranslationsZip(pageId: string, projectId: string) {
  // Fetch translations from the API
  const response = await fetch(
    `/api/translations?pageId=${pageId}&projectId=${projectId}`
  )
  const translations = await response.json()

  // Create ZIP file
  const zip = new JSZip()

  // Add each language as a separate file
  Object.entries(translations).forEach(([langCode, content]) => {
    const jsonContent = JSON.stringify(content, null, 2)
    zip.file(`${langCode}.json`, jsonContent)
  })

  // Generate and download ZIP
  const blob = await zip.generateAsync({ type: 'blob' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = 'translations.zip'

  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  window.URL.revokeObjectURL(url)
}

export function RightActions({ getAllColumns }: RightActionsProps) {
  const selectedProject = useSelectedProject()
  const selectedPage = useSelectedPage()

  return (
    <div className="flex items-center space-x-2">
      <Button
        variant="outline"
        size="sm"
        onClick={() => {
          if (selectedPage && selectedProject) {
            downloadTranslationsZip(selectedPage.id, selectedProject.id)
          }
        }}
      >
        <Download />
        Download
      </Button>

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" size="sm">
            <Settings2 />
            View
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-[150px]">
          <DropdownMenuLabel>Toggle columns</DropdownMenuLabel>
          <DropdownMenuSeparator />
          {getAllColumns()
            .filter(
              (column) =>
                typeof column.accessorFn !== 'undefined' && column.getCanHide()
            )
            .map((column) => {
              return (
                <DropdownMenuCheckboxItem
                  key={column.id}
                  className="capitalize"
                  checked={column.getIsVisible()}
                  onCheckedChange={(value) => column.toggleVisibility(!!value)}
                >
                  {column.id}
                </DropdownMenuCheckboxItem>
              )
            })}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}
