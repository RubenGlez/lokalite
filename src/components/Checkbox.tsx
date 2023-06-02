import React, { useRef, useId } from "react";
import LabelInput from "./LabelInput";

export interface CheckboxProps {
  label?: string;
  defaultChecked?: boolean;
  handleChange?: (checked: boolean) => void;
  className?: string;
  name?: string;
}

export default function Checkbox({
  label,
  defaultChecked,
  handleChange,
  className = "",
  name,
}: CheckboxProps) {
  const id = useId();
  const checkboxRef = useRef<HTMLInputElement>(null);
  const onChange = () => {
    if (handleChange && checkboxRef.current) {
      handleChange(checkboxRef.current.checked);
    }
  };

  return (
    <div className={`flex items-center ${className}`}>
      <input
        name={name}
        id={id}
        type="checkbox"
        ref={checkboxRef}
        defaultChecked={defaultChecked}
        onChange={onChange}
        className="w-5 h-5 rounded"
      />
      {label && (
        <div className="ml-2">
          <LabelInput id={id} text={label} />
        </div>
      )}
    </div>
  );
}
