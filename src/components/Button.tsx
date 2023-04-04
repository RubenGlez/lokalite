import React from "react";

interface ButtonProps {
  text: string;
  type?: "button" | "submit" | "reset";
  onClick?: () => void;
  isDisabled?: boolean;
  template?: "primary" | "secondary";
  className?: string;
}

export default function Button({
  text,
  onClick,
  isDisabled,
  type = "button",
  template = "primary",
  className,
}: ButtonProps) {
  const primaryClasses = "text-slate-100 bg-sky-600 hover:bg-sky-700";
  const secondaryClasses = "text-slate-100 bg-slate-600 hover:bg-sky-700";
  const buttonClasses = `px-4 py-2 border border-transparent text-sm font-medium rounded-md focus:outline-none ${
    template === "primary" ? primaryClasses : secondaryClasses
  }`;
  const disabledClasses =
    "px-4 py-2 border border-transparent text-sm font-medium rounded-md text-slate-100 bg-slate-400 cursor-not-allowed";

  return (
    <div className={`inline-block ${className}`}>
      <button
        type={type}
        onClick={onClick}
        className={isDisabled ? disabledClasses : buttonClasses}
        disabled={isDisabled}
      >
        {text}
      </button>
    </div>
  );
}
