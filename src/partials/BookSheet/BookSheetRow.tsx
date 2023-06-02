import { ChangeEvent, useRef } from "react";
import BookSheetCell from "./BookSheetCell";
import { BookSheetRowProps } from "./types";
import { debounce } from "@/utils/debounde";

const UPDATE_DEELAY_MS = 2000;

export default function BookSheetRow({
  translationId,
  cells,
  updateTranslation,
  sheetId,
  handleOpenSidebar,
}: BookSheetRowProps) {
  const rowRef = useRef<HTMLDivElement>(null);
  const getRowData = () => {
    if (!rowRef.current) return;
    const keyInputs = rowRef.current.getElementsByTagName("input");
    const langInputs = rowRef.current.getElementsByTagName("textarea");
    const copies = Array.from(langInputs).reduce(
      (acc: Record<string, string>, curr) => {
        const { name, value } = curr;
        const [translationId, colLabel] = name.split("_");
        acc[colLabel] = value;
        return acc;
      },
      {}
    );
    const updatePayload = {
      id: translationId,
      key: keyInputs[0].value,
      copies,
      sheet_id: sheetId,
    };
    return updatePayload;
  };
  const updateRow = () => {
    const rowData = getRowData();
    if (rowData) updateTranslation(rowData);
  };
  const debouncedUpdateRow = debounce(updateRow, UPDATE_DEELAY_MS);
  const handleChangeCell = (
    e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    debouncedUpdateRow();
  };

  return (
    <div ref={rowRef} className="flex border-b border-slate-700">
      {cells.map((cell) => {
        return (
          <BookSheetCell
            key={`rowId:${translationId}_colLabel:${cell.colLabel}`}
            value={cell.value}
            colWidth={cell.colWidth}
            colType={cell.colType}
            colLabel={cell.colLabel}
            translationId={translationId}
            handleChangeCell={handleChangeCell}
            handleOpenSidebar={handleOpenSidebar}
          />
        );
      })}
    </div>
  );
}
