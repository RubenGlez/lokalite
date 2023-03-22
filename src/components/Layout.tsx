import { classNames } from "@/utils";
import { ReactNode } from "react";

interface LayoutProps {
  children: ReactNode;
  title: string;
}

const navigation = [
  { name: "Dashboard", href: "/" },
  { name: "Example", href: "/example" },
];

export default function Layout({ children, title }: LayoutProps) {
  return (
    <div className="h-full bg-slate-800">
      <div className="border-b border-slate-700 flex items-center justify-between px-4 py-2">
        <div>
          <span className="text-xl text-slate-100">Lokalite</span>
        </div>
        <nav>
          <ul className="flex items-center gap-x-2">
            {navigation.map((item, index) => {
              const isCurrent = false;
              return (
                <li key={`${item.name}_${index}`}>
                  <a
                    href={item.href}
                    className="inline-flex px-4 py-2 text-base text-slate-400 hover:text-slate-200"
                    aria-current={isCurrent ? "page" : undefined}
                  >
                    {item.name}
                  </a>
                </li>
              );
            })}
          </ul>
        </nav>
      </div>

      <div>
        <header className="border-b border-slate-700 mx-4 py-3">
          <h1 className="text-base text-slate-500">{title}</h1>
        </header>
        <main>{children}</main>
      </div>
    </div>
  );
}
