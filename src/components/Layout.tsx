import { Fragment, ReactNode } from "react";
import Link from "next/link";
import {
  ArchiveBoxIcon,
  FireIcon,
  HomeIcon,
  RectangleStackIcon,
} from "@heroicons/react/24/outline";
import Text from "@/components/Text";
import { useRouter } from "next/router";
import { cls } from "@/utils";

interface LayoutProps {
  children: ReactNode;
}

const navigation = [
  { name: "Dashboard", href: "/", Icon: HomeIcon },
  { name: "Books", href: "/books", Icon: RectangleStackIcon },
  { name: "Sandbox", href: "/sandbox", Icon: ArchiveBoxIcon },
];

export default function Layout({ children }: LayoutProps) {
  const router = useRouter();

  return (
    <div className="h-full bg-slate-900 flex">
      <div className="border-r border-slate-700 w-14">
        <div className="flex items-center justify-center h-12">
          <FireIcon className="h-8 w-8 text-sky-500" />
        </div>
        <nav className="py-4">
          <ul className="flex flex-col items-center gap-4">
            {navigation.map(({ name, href, Icon }, index) => {
              const isActive = router.pathname === href;
              return (
                <li key={`${name}_${index}`}>
                  <Link
                    href={href}
                    className={cls({
                      "flex items-center justify-center w-10 h-10 rounded":
                        true,
                      "bg-slate-800 text-slate-100": isActive,
                      "text-slate-500": !isActive,
                      "hover:text-slate-100 hover:bg-slate-800": true,
                    })}
                  >
                    <Icon className="h-6 w-6 text-color-inherit" />
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>
      </div>

      <div className="flex flex-1 flex-col overflow-hidden">
        <div className="border-b border-slate-700 h-12">
          <header className="flex items-center gap-2 h-full px-4">
            <Text as="h1" size="xs">
              Lokalite
            </Text>
            {router.pathname
              .split("/")
              .slice(1)
              .map((path) => (
                <Fragment key={path}>
                  <Text size="xs" color="secondary">
                    {"/"}
                  </Text>
                  <Text as="h1" size="xs" key={path}>
                    {path}
                  </Text>
                </Fragment>
              ))}
          </header>
        </div>
        <main className="flex flex-1 overflow-auto">
          <div className="w-full">{children}</div>
        </main>
      </div>
    </div>
  );
}
