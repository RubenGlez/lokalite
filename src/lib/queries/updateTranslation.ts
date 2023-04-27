import { Translation } from "../database.types";
import { supabase } from "../supabaseClient";

export type UpdateTranslationPayload = Pick<
  Translation,
  "id" | "key" | "sheet_id" | "copies"
>;

export default function updateTranslation({
  id,
  key,
  sheet_id,
  copies,
}: UpdateTranslationPayload) {
  return supabase
    .from("translations")
    .update({ id, key, sheet_id, copies, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .order("created_at", { ascending: true });
}
