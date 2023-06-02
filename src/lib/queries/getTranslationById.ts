import { Translation } from "../database.types";
import { supabase } from "../supabaseClient";

export default function getTranslationById(id: Translation["id"]) {
  return supabase.from("translations").select().eq("id", id);
}
