import { ReactNode } from "react";

export interface TextProps {
  as?: "a" | "p" | "span" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6";
  children: ReactNode;
  size?: "xs" | "sm" | "base" | "lg";
  color?: "primary" | "secondary";
  weight?: "thin" | "normal" | "bold";
  align?: "left" | "center" | "right";
  className?: string;
}

const colors = {
  primary: "text-slate-100",
  secondary: "text-slate-400",
};

const sizes = {
  xs: "text-xs",
  sm: "text-sm",
  base: "text-base",
  lg: "text-lg",
};

const weights = {
  thin: "text-thin",
  normal: "text-normal",
  bold: "text-bold",
};

const aligns = {
  left: "text-left",
  center: "text-center",
  right: "text-right",
};

export default function Text({
  as = "span",
  children = "",
  size = "base",
  color = "primary",
  weight = "normal",
  align = "left",
  className = "",
}: TextProps) {
  const TextComponent = as;

  return (
    <TextComponent
      className={`${colors[color]} ${sizes[size]} ${weights[weight]} ${aligns[align]} ${className}`}
    >
      {children}
    </TextComponent>
  );
}
