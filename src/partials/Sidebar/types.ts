import { Book, Translation } from "@/lib/database.types";

export interface SidebarProps {
  handleCloseSidebar: () => void;
  translationId: Translation["id"] | null;
  languages: Book["languages"];
  defaultLanguage: Book["default_language"];
}
