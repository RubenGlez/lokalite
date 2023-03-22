import { ReactNode } from "react";

interface TableRowProps {
  children: ReactNode;
}

export default function TableRow({ children }: TableRowProps) {
  return <tr>{children}</tr>;
}
