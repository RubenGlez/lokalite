'use client'
import { usePathname } from 'next/navigation'
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator
} from '~/components/ui/breadcrumb'

interface Breadcrumb {
  href: string
  label: string
  isCurrentPage: boolean
}

function generateBreadcrumbs(pathname: string): Breadcrumb[] {
  const paths = pathname.replace(/\/$/, '').split('/').filter(Boolean)

  const breadcrumbs: Breadcrumb[] = []

  let currentPath = ''

  paths.forEach((segment, index) => {
    currentPath += `/${segment}`
    const label = segment
      .split('-')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ')

    breadcrumbs.push({
      href: currentPath,
      label,
      isCurrentPage: index === paths.length - 1
    })
  })

  return breadcrumbs
}

export function Breadcrumbs() {
  const pathname = usePathname()
  const breadcrumbs = generateBreadcrumbs(pathname)

  return (
    <Breadcrumb>
      <BreadcrumbList>
        {breadcrumbs.map((breadcrumb, index) => (
          <div key={breadcrumb.href}>
            <BreadcrumbItem className="hidden md:block">
              {breadcrumb.isCurrentPage ? (
                <BreadcrumbPage>{breadcrumb.label}</BreadcrumbPage>
              ) : (
                <BreadcrumbLink href={breadcrumb.href}>
                  {breadcrumb.label}
                </BreadcrumbLink>
              )}
            </BreadcrumbItem>
            {index < breadcrumbs.length - 1 && (
              <BreadcrumbSeparator className="hidden md:block" />
            )}
          </div>
        ))}
      </BreadcrumbList>
    </Breadcrumb>
  )
}
