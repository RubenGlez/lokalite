import DashboardHeader from "./_components/dashboard-header";

export default function DashboardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <>
      <DashboardHeader />
      <main className="flex flex-col p-24">{children}</main>
    </>
  );
}
