import Text from "@/components/Text";
import { BookSheetCellProps } from "./types";

export default function BookSheetCell({
  value,
  colWidth,
  colType,
  colLabel,
  translationId,
  handleChangeCell,
}: BookSheetCellProps) {
  return (
    <div className={`border-r border-slate-700 ${colWidth}`}>
      {colType === "index" ? (
        <div className="flex items-center justify-center px-2 w-full h-full">
          <Text size="sm">{value}</Text>
        </div>
      ) : colType === "key" ? (
        <input
          className="w-full text-slate-100 text-sm rounded-0 bg-slate-900 border-0 outline-none focus:border focus:border-sky-500 px-2"
          name={`${translationId}_${colLabel}`}
          type="text"
          defaultValue={value}
          onChange={handleChangeCell}
        />
      ) : (
        <textarea
          className="resize-none w-full text-slate-100 text-sm rounded-0 bg-slate-900 border-0 outline-none focus:border focus:border-sky-500 px-2"
          name={`${translationId}_${colLabel}`}
          defaultValue={value}
          onChange={handleChangeCell}
        />
      )}
    </div>
  );
}
