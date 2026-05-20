import '~/styles/globals.css'

import { GeistSans } from 'geist/font/sans'
import { type Metadata } from 'next'

import { TRPCReactProvider } from '~/trpc/react'
import { Toaster } from '~/components/ui/toaster'
import { ThemeProvider } from '~/lib/theme'
import { ReactNode } from 'react'
import { TooltipProvider } from '@radix-ui/react-tooltip'

export const metadata: Metadata = {
  title: 'Lokalite',
  description: 'Lokalite is a tool for creating multilingual websites.',
  icons: [{ rel: 'icon', url: '/favicon.ico' }]
}

const ENABLE_REACT_SCAN = false

export default async function RootLayout({
  children
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en" className={`${GeistSans.variable}`}>
      {ENABLE_REACT_SCAN && (
        <head>
          <script
            src="https://unpkg.com/react-scan/dist/auto.global.js"
            async
          />
        </head>
      )}

      <body>
        <TRPCReactProvider>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            <TooltipProvider>{children}</TooltipProvider>
          </ThemeProvider>
        </TRPCReactProvider>
        <Toaster />
      </body>
    </html>
  )
}
