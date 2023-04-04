import React from "react";

export interface LabelInputProps {
  id?: string;
  text: string;
}

export default function LabelInput({ id, text }: LabelInputProps) {
  return (
    <label htmlFor={id} className="text-slate-100 text-left text-sm">
      {text}
    </label>
  );
}
