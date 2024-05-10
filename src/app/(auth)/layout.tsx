export default function AuthLayout({
  children
}: Readonly<{
  children: React.ReactNode
}>) {
  return <main className="flex flex-col p-24">{children}</main>
}
