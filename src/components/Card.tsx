import { ReactNode } from "react";
import Text from "./Text";

interface CardProps {
  title: ReactNode;
  subtitle: ReactNode;
  description: ReactNode;
  onClick?: () => void;
}

export default function Card({
  title,
  subtitle,
  description,
  onClick,
}: CardProps) {
  return (
    <div
      className="border border-slate-700 rounded hover:border-slate-400 cursor-pointer"
      onClick={onClick}
    >
      <div className="px-6 py-4">
        <Text as="h3">{title}</Text>
        <Text
          as="h6"
          size="xs"
          color="secondary"
          weight="thin"
          className="mb-4"
        >
          {subtitle}
        </Text>
        <Text size="xs">{description}</Text>
      </div>
    </div>
  );
}
