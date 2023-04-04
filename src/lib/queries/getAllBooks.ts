import { supabase } from "../supabaseClient";

export default function getAllBooks() {
  return supabase.from("books").select();
}
