import { Translation } from "../database.types";
import { supabase } from "../supabaseClient";

export type UpdateTranslationBody = Pick<Translation, "id" | "copies" | "key">;

export default function updateTranslation(translation: UpdateTranslationBody) {
  return supabase
    .from("translations")
    .update({ copies: translation.copies, key: translation.key })
    .eq("id", translation.id);
}
