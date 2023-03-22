import { cls } from "@/utils";
import { ReactNode } from "react";

interface TableHeaderCell {
  children: ReactNode;
  index: number;
}

export default function TableHeaderCell({ children, index }: TableHeaderCell) {
  const isFirstCell = index === 0;
  return (
    <th
      className={cls({
        "text-left text-base text-slate-200 px-2 py-2 border-t border-b border-r border-slate-600 bg-slate-700":
          true,
        "border-l": isFirstCell,
      })}
    >
      {children}
    </th>
  );
}
