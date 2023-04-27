import { Sheet } from "../database.types";
import { supabase } from "../supabaseClient";

export default function getTranslationsBySheetId(sheetId: Sheet["id"]) {
  return supabase
    .from("translations")
    .select()
    .eq("sheet_id", sheetId)
    .order("created_at", { ascending: true });
}
