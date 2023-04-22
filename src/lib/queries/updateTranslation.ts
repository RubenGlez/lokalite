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
    .upsert({ id, key, sheet_id, copies })
    .eq("id", id)
    .select();
}
