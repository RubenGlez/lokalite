import { Book, Sheet, Translation } from "@/lib/database.types";
import { UpdateTranslationPayload } from "@/lib/queries/updateTranslation";
import { ChangeEventHandler, FocusEventHandler } from "react";

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
  colLabel: SheetColumn["label"];
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
  sheetId: Translation["sheet_id"];
  updateTranslation: (payload: UpdateTranslationPayload) => Promise<void>;
}

export interface BookSheetCellProps
  extends SheetCell,
    Pick<BookSheetRowProps, "translationId"> {
  handleChangeCell: ChangeEventHandler<HTMLInputElement | HTMLTextAreaElement>;
}
