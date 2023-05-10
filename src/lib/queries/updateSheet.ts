import { Sheet } from "../database.types";
import { supabase } from "../supabaseClient";

export type UpdateSheetBody = Pick<Sheet, "id" | "description" | "name">;

export default function updateSheet(sheet: UpdateSheetBody) {
  return supabase
    .from("sheets")
    .update({ ...sheet, updated_at: new Date().toISOString() })
    .eq("id", sheet.id);
}
