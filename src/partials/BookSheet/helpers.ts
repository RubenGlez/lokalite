import { Translation } from "@/lib/database.types";
import { SheetProps, SheetColumn } from "./types";

export const COLUMN_WIDTHS = {
  index: "w-12",
  key: "w-60",
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
    { type: "key", label: "Key" },
    { type: "defaultLang", label: defaultLang ?? "" },
    ...langColumns,
  ];
  return sheetColumns;
};

export const DEFAULT_ROW: Translation = {
  copies: {},
  created_at: "",
  id: 0,
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
    } else {
      value = row.copies?.[col.label];
    }

    return {
      colType: col.type,
      colWidth: COLUMN_WIDTHS[col.type],
      value,
    };
  });
};
