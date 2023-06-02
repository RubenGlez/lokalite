import React, { ChangeEvent, useId } from "react";
import LabelInput from "./LabelInput";

export interface TextAreaProps {
  label?: string;
  placeholder?: string;
  defaultValue?: string;
  handleChange?: (val: string | undefined) => void;
  className?: string;
  name?: string;
}

export default function TextArea({
  label,
  placeholder,
  defaultValue,
  handleChange,
  className = "",
  name,
}: TextAreaProps) {
  const id = useId();

  const onChange = (e: ChangeEvent<HTMLTextAreaElement>) => {
    handleChange?.(e.target.value);
  };

  return (
    <div className={`flex flex-col ${className}`}>
      {label && (
        <div className="mb-1">
          <LabelInput id={id} text={label} />
        </div>
      )}
      <textarea
        name={name}
        id={id}
        className="px-3 py-2 border border-slate-700 bg-slate-900 focus:outline-none focus:border-slate-100 rounded-md text-left text-sm text-slate-100"
        placeholder={placeholder}
        defaultValue={defaultValue}
        onChange={onChange}
      />
    </div>
  );
}
