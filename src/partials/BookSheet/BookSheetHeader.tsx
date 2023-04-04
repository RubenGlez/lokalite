import Text from "@/components/Text";
import { BookSheetHeaderProps } from "./types";
import { COLUMN_WIDTHS } from "./helpers";

export default function BookSheetHeader({ columns }: BookSheetHeaderProps) {
  return (
    <div className="flex h-8 border-b border-slate-700 bg-slate-800">
      {columns.map((col, index) => {
        const colClassName = COLUMN_WIDTHS[col.type];
        const isDefault = col.type === "defaultLang";
        return (
          <div
            key={`header_col_${index}`}
            className={`flex items-center px-2 border-r border-slate-700 ${colClassName}`}
          >
            <Text>{col.label}</Text>
            {isDefault && <Text size="xs">(default)</Text>}
          </div>
        );
      })}
    </div>
  );
}
