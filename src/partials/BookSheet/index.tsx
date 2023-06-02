import BookSheetHeader from "./BookSheetHeader";
import BookSheetContent from "./BookSheetContent";
import { SheetProps } from "./types";
import { getSheetColumns } from "./helpers";

export default function BookSheet({
  languages = [],
  defaultLanguage,
  sheetId,
  handleOpenSidebar,
}: SheetProps) {
  const columns = getSheetColumns(languages, defaultLanguage);

  return (
    <div>
      <BookSheetHeader columns={columns} />
      <BookSheetContent
        sheetId={sheetId}
        columns={columns}
        handleOpenSidebar={handleOpenSidebar}
      />
    </div>
  );
}
