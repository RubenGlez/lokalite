import BookSheetRow from "./BookSheetRow";
import { BookSheetContentProps } from "./types";
import { getCells } from "./helpers";
import { useTranslations } from "@/hooks/useTranslations";
import Text from "@/components/Text";

export default function BookSheetContent({
  sheetId,
  columns,
}: BookSheetContentProps) {
  const {
    getterError,
    getterIsLoading,
    translations,
    updaterError,
    updaterIsLoading,
    updateTranslation,
  } = useTranslations({
    sheetId,
  });

  return (
    <div className="relative">
      {getterIsLoading && (
        <div className="absolute top-0 right-0 bottom-0 left-0 bg-slate-900 bg-opacity-80 flex items-center justify-center">
          <Text>Getting...</Text>
        </div>
      )}
      {updaterIsLoading && (
        <div className="absolute top-0 right-0 bottom-0 left-0 bg-slate-900 bg-opacity-80 flex items-center justify-center">
          <Text>Updating...</Text>
        </div>
      )}
      {translations.map((row, index) => {
        const cells = getCells(columns, row, index);
        return (
          <BookSheetRow
            key={`row_${index}`}
            translationId={row.id}
            sheetId={sheetId}
            cells={cells}
            updateTranslation={updateTranslation}
          />
        );
      })}
    </div>
  );
}
