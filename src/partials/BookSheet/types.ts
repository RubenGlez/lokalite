import { Book, Sheet, Translation } from "@/lib/database.types";

export interface SheetProps {
  languages: Book["languages"];
  defaultLanguage: Book["default_language"];
  sheetId: Sheet["id"];
}

export interface SheetColumn {
  label: string;
  type: "index" | "key" | "defaultLang" | "lang";
}

export interface SheetCell {
  colType: SheetColumn["type"];
  colWidth: string;
  value: string;
}

export interface BookSheetHeaderProps {
  columns: SheetColumn[];
}

export interface BookSheetContentProps {
  sheetId: number;
  columns: SheetColumn[];
}

export interface BookSheetRowProps {
  cells: SheetCell[];
  translationId: Translation["id"];
}

export interface BookSheetCellProps extends SheetCell {}
