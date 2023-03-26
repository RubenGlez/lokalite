import { ReactNode } from "react";

interface TableHeaderCell {
  children: ReactNode;
}

export default function TableHeaderCell({ children }: TableHeaderCell) {
  return (
    <th className="text-left text-sm text-slate-300 px-2 py-2 border-b border-r border-slate-800 bg-slate-700">
      {children}
    </th>
  );
}
