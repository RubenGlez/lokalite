import { supabase } from "../supabaseClient";

export default function getSheetById(sheetId: number) {
  return supabase.from("sheets").select().eq("id", sheetId);
}
