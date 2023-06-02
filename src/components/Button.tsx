import React from "react";

interface ButtonProps {
  text: string;
  type?: "button" | "submit" | "reset";
  onClick?: () => void;
  isDisabled?: boolean;
  template?: "primary" | "secondary" | "danger";
  className?: string;
}

export default function Button({
  text,
  onClick,
  isDisabled,
  type = "button",
  template = "primary",
  className = "",
}: ButtonProps) {
  const dangerClasses = "text-red-100 bg-red-700 hover:bg-red-600";
  const primaryClasses = "text-sky-100 bg-sky-700 hover:bg-sky-600";
  const secondaryClasses = "text-slate-100 bg-slate-700 hover:bg-slate-600";
  const templateClasses = {
    primary: primaryClasses,
    secondary: secondaryClasses,
    danger: dangerClasses,
  };
  const disabledClasses = "cursor-not-allowed opacity-50";
  const buttonClasses = `px-4 py-2 border border-transparent text-sm font-medium rounded-md focus:outline-none ${
    template ? templateClasses[template] : ""
  } ${isDisabled ? disabledClasses : ""}`;

  return (
    <div className={`inline-block ${className}`}>
      <button
        type={type}
        onClick={onClick}
        className={buttonClasses}
        disabled={isDisabled}
      >
        {text}
      </button>
    </div>
  );
}
