import React from "react";
import Checkbox, { CheckboxProps } from "./Checkbox";
import LabelInput from "./LabelInput";

interface CheckGroupProps {
  label?: string;
  handleChange?: (checked: boolean) => void;
  className?: string;
  checkboxes: CheckboxProps[];
  columns?: 1 | 2 | 3 | 4;
}

const columClasses = {
  col_1: "grid-cols-1",
  col_2: "grid-cols-2",
  col_3: "grid-cols-3",
  col_4: "grid-cols-4",
};

export default function CheckGroup({
  label,
  handleChange,
  className,
  checkboxes,
  columns = 1,
}: CheckGroupProps) {
  const columnClass = columClasses[`col_${columns}`];
  return (
    <div className={`flex flex-col ${className}`}>
      {label && (
        <div className="mb-1">
          <LabelInput text={label} />
        </div>
      )}
      <div className={`grid grid-cols-4 gap-4 ${columnClass}`}>
        {checkboxes.map((checkbox, index) => (
          <Checkbox
            key={`checkbox_${index}`}
            name={checkbox.name}
            defaultChecked={checkbox.defaultChecked}
            handleChange={handleChange}
            label={checkbox.label}
          />
        ))}
      </div>
    </div>
  );
}
