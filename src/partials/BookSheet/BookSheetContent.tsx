import BookSheetRow from "./BookSheetRow";
import { BookSheetContentProps } from "./types";
import { getCells } from "./helpers";
import { useTranslations } from "@/hooks/useTranslations";
import { useAppContext } from "@/contexts/AppContext";
import Button from "@/components/Button";
import { Translation } from "@/lib/database.types";
import Text from "@/components/Text";

export default function BookSheetContent({
  sheetId,
  columns,
}: BookSheetContentProps) {
  const {
    // get
    error,
    getTranslations,
    isLoading,
    translations,
    // update
    errorUpdating,
    isUpdating,
    updateTranslation,
    // create
    createAndGet,
    errorCreatingAndGetting,
    isCreatingAndGetting,
  } = useTranslations({
    sheetId,
  });
  const createEmptyRows = () => {
    const emptyRows = Array.from({ length: 10 }).fill({
      sheet_id: sheetId,
    });
    createAndGet(emptyRows as Translation[]);
  };

  return (
    <div className="relative">
      {isCreatingAndGetting && (
        <div className="absolute top-0 right-0 bottom-0 left-0 bg-slate-900 flex justify-center items-center bg-opacity-90">
          <Text>Creando nuevas filas...</Text>
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
      <div className="pt-4 pl-4">
        <Button text="Añadir 10 filas" onClick={createEmptyRows} />
      </div>
    </div>
  );
}
