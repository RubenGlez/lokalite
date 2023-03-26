import { ChangeEventHandler } from "react";
import InputCell from "./InputCell";

interface TableCell {
  value: string;
  onChange: ChangeEventHandler<HTMLInputElement>;
}

export default function TableCell({ value, onChange }: TableCell) {
  return (
    <td className="text-left text-sm text-slate-300 border-b border-r border-slate-800 min-w-0">
      <InputCell value={value} onChange={onChange} />
    </td>
  );
}
