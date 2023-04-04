import { Book } from "../database.types";
import { supabase } from "../supabaseClient";

export type CreateBookBody = Pick<
  Book,
  "name" | "description" | "default_language" | "languages"
>;

export default function createBook(book: CreateBookBody) {
  return supabase.from("books").insert(book);
}
