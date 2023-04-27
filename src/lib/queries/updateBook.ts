import { Book } from "../database.types";
import { supabase } from "../supabaseClient";

export type UpdateBookBody = Pick<
  Book,
  "id" | "name" | "description" | "default_language" | "languages"
>;

export default function updateBook(book: UpdateBookBody) {
  return supabase
    .from("books")
    .update({ ...book, updated_at: new Date().toISOString() })
    .eq("id", book.id);
}
