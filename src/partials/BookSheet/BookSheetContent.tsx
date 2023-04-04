import BookSheetRow from "./BookSheetRow";
import { BookSheetContentProps } from "./types";
import { getCells } from "./helpers";
import { useTranslations } from "@/hooks/useTranslations";

export default function BookSheetContent({
  sheetId,
  columns,
}: BookSheetContentProps) {
  const { translations } = useTranslations({ sheetId });

  return (
    <div>
      {translations.map((row, index) => {
        const cells = getCells(columns, row, index);
        return (
          <BookSheetRow
            key={`row_${index}`}
            cells={cells}
            translationId={row.id}
          />
        );
      })}
    </div>
  );
}
