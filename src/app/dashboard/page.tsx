import SheetSwitcher from './_components/sheet-switcher'
import { TranslationsTable } from './_components/translations-table'
import SheetSettings from './_components/sheet-settings'

export default function Dashboard() {
  return (
    <div className="flex flex-col flex-1 px-4 py-8 gap-y-4">
      <div className="flex items-center justify-between">
        <div>
          <SheetSwitcher />
        </div>

        <div className="flex items-center gap-2">
          <SheetSettings />
        </div>
      </div>

      <div className="flex-1">
        <TranslationsTable />
      </div>
    </div>
  )
}
