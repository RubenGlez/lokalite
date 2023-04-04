import { Sheet } from "../database.types";
import { supabase } from "../supabaseClient";

export type CreateSheetBody = Pick<Sheet, "name" | "description" | "book_id">;

export default function createSheet(sheet: CreateSheetBody) {
  return supabase.from("sheets").insert(sheet).select();
}
