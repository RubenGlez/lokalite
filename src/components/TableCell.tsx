import { cls } from "@/utils";
import { ChangeEventHandler } from "react";
import InputCell from "./InputCell";

interface TableCell {
  value: string;
  onChange: ChangeEventHandler<HTMLInputElement>;
  index: number;
}

export default function TableCell({ value, onChange, index }: TableCell) {
  const isFirstCell = index === 0;
  return (
    <td
      className={cls({
        "text-left text-base text-slate-200 border-b border-r border-slate-600":
          true,
        "border-l": isFirstCell,
      })}
    >
      <InputCell value={value} onChange={onChange} />
    </td>
  );
}
