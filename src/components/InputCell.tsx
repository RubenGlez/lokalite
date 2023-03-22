import { ChangeEventHandler } from "react";

interface InputCellProps {
  value: string;
  onChange: ChangeEventHandler<HTMLInputElement>;
}

export default function InputCell({ value, onChange }: InputCellProps) {
  return (
    <input
      className="bg-transparent py-1 px-2 border-0	"
      value={value}
      onChange={onChange}
    />
  );
}
