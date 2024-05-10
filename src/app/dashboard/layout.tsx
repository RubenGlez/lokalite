import DashboardHeader from './_components/dashboard-header'

export default function DashboardLayout({
  children
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <div className="flex flex-col min-h-screen">
      <DashboardHeader />
      <main className="flex flex-col flex-1">{children}</main>
    </div>
  )
}
