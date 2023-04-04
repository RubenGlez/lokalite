import { useUpdateTranslation } from "@/hooks/useUpdateTranslation";
import BookSheetCell from "./BookSheetCell";
import { BookSheetRowProps } from "./types";

export default function BookSheetRow({
  cells,
  translationId,
}: BookSheetRowProps) {
  const { trigger } = useUpdateTranslation({ translationId });

  return (
    <div className="flex border-b border-slate-700">
      {cells.map((cell, idx) => {
        return (
          <BookSheetCell
            key={`cell_${idx}`}
            value={cell.value}
            colWidth={cell.colWidth}
            colType={cell.colType}
          />
        );
      })}
    </div>
  );
}
