import Text from "@/components/Text";
import { BookSheetCellProps } from "./types";
import { SparklesIcon } from "@heroicons/react/24/outline";

export default function BookSheetCell({
  value,
  colWidth,
  colType,
  colLabel,
  translationId,
  handleChangeCell,
  handleOpenSidebar,
}: BookSheetCellProps) {
  return (
    <div
      className={`cellWrapper border-r border-slate-700 ${colWidth} shrink-0 leading-zero relative`}
    >
      {colType === "index" ? (
        <div className="flex items-center justify-center px-2 w-full h-full">
          <Text size="sm">{value}</Text>
        </div>
      ) : colType === "key" ? (
        <input
          className="w-full h-full text-slate-100 text-sm rounded-0 bg-slate-900 outline-none focus:border focus:border-sky-500 px-2 box-border border border-transparent"
          name={`${translationId}_${colLabel}`}
          type="text"
          defaultValue={value}
          onChange={handleChangeCell}
        />
      ) : (
        <textarea
          className="resize-none w-full text-slate-100 text-sm rounded-0 bg-slate-900 outline-none focus:border focus:border-sky-500 px-2 box-border border border-transparent"
          name={`${translationId}_${colLabel}`}
          defaultValue={value}
          onChange={handleChangeCell}
        />
      )}

      {colType !== "index" && (
        <div
          className="cellAction opacity-0 transition-opacity absolute top-0 bottom-0 right-0 flex items-center justify-center h-full"
          onClick={handleOpenSidebar(translationId)}
        >
          <div className="bg-slate-800 cursor-pointer p-1 rounded mr-2">
            <SparklesIcon className="h-4 w-4 text-slate-100" />
          </div>
        </div>
      )}
    </div>
  );
}
