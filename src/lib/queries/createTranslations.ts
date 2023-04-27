import { Translation } from "../database.types";
import { supabase } from "../supabaseClient";

export type CreateTranslationsPayload = {
  translations: Translation[];
};

export default function createTranslations({
  translations,
}: CreateTranslationsPayload) {
  return supabase
    .from("translations")
    .insert(translations)
    .select()
    .order("created_at", { ascending: true });
}
