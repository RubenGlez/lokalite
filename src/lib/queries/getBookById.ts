import { supabase } from "../supabaseClient";

export default function getBookById(bookId: number) {
  return supabase.from("books").select().eq("id", bookId);
}
