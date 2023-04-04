import { Book } from "../database.types";
import { supabase } from "../supabaseClient";

export default function getSheetsByBookId(bookId: Book["id"]) {
  return supabase.from("sheets").select().eq("book_id", bookId);
}
