import { Translation } from "@/lib/database.types";
import { SheetProps, SheetColumn } from "./types";

export const COLUMN_WIDTHS = {
  index: "w-8",
  key: "w-48",
  defaultLang: "w-48",
  lang: "w-48",
};

export const getSheetColumns = (
  langs: SheetProps["languages"],
  defaultLang: SheetProps["defaultLanguage"]
) => {
  const langColumns: SheetColumn[] = langs
    ? langs.map((lang) => ({
        type: "lang",
        label: lang,
      }))
    : [];
  const sheetColumns: SheetColumn[] = [
    { type: "index", label: "" },
    { type: "key", label: "key" },
    { type: "defaultLang", label: defaultLang ?? "" },
    ...langColumns,
  ];
  return sheetColumns;
};

export const DEFAULT_ROW: Omit<Translation, "id"> = {
  copies: {},
  created_at: "",
  key: "",
  sheet_id: 0,
  updated_at: "",
};

export const getCells = (
  columns: SheetColumn[],
  row: Translation,
  index: number
) => {
  return columns.map((col) => {
    let value = "";
    if (col.type === "index") {
      value = String(index);
    } else if (col.type === "key") {
      value = row.key ?? "";
    } else {
      value = row.copies?.[col.label] ?? "";
    }

    return {
      colLabel: col.label,
      colType: col.type,
      colWidth: COLUMN_WIDTHS[col.type],
      value,
    };
  });
};
