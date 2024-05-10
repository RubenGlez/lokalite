import SheetSwitcher from './_components/sheet-switcher'
import SheetSettings from './_components/sheet-settings'
import { TranslationsTable } from './_components/translations-table'

export default function Dashboard() {
  return (
    <div className="flex-1 p-8 pt-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
        <div className="flex items-center space-x-4">
          <SheetSwitcher />
          <SheetSettings />
        </div>
      </div>

      <div>
        <TranslationsTable />
      </div>
    </div>
  )
}
