import ProjectSwitcher from './project-switcher'
import { UserNav } from './user-nav'

export default function DashboardHeader() {
  return (
    <header className="border-b">
      <div className="flex h-16 items-center justify-between px-4">
        <ProjectSwitcher />
        <UserNav />
      </div>
    </header>
  )
}
