type ClsProps = Record<string, boolean>;

export function cls(classes: ClsProps) {
  return Object.keys(classes)
    .filter((key) => classes[key])
    .join(" ");
}
