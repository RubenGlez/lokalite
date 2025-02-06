import '~/styles/globals.css'

import { GeistSans } from 'geist/font/sans'
import { type Metadata } from 'next'

import { TRPCReactProvider } from '~/trpc/react'
import { Toaster } from '~/components/ui/toaster'
import { ThemeProvider } from '~/lib/theme'

export const metadata: Metadata = {
  title: 'Lokalite',
  description: 'Lokalite is a tool for creating multilingual websites.',
  icons: [{ rel: 'icon', url: '/favicon.ico' }]
}

const ENABLE_REACT_SCAN = false

export default async function RootLayout({
  children
}: Readonly<{ children: React.ReactNode }>) {
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
            {children}
          </ThemeProvider>
        </TRPCReactProvider>
        <Toaster />
      </body>
    </html>
  )
}
