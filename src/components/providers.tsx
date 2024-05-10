'use client'

import { ThemeProvider } from 'next-themes'
import { Provider as BalancerProvider } from 'react-wrap-balancer'

export function Providers({
  children
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <ThemeProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
    >
      <BalancerProvider>{children}</BalancerProvider>
    </ThemeProvider>
  )
}
