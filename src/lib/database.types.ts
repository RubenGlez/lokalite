import { PostgrestError } from "@supabase/supabase-js";

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json }
  | Json[];

export interface Database {
  public: {
    Tables: {
      books: {
        Row: {
          created_at: string | null;
          default_language: string | null;
          description: string | null;
          id: number;
          languages: string[] | null;
          name: string | null;
          updated_at: string | null;
        };
        Insert: {
          created_at?: string | null;
          default_language?: string | null;
          description?: string | null;
          id?: number;
          languages?: string[] | null;
          name?: string | null;
          updated_at?: string | null;
        };
        Update: {
          created_at?: string | null;
          default_language?: string | null;
          description?: string | null;
          id?: number;
          languages?: string[] | null;
          name?: string | null;
          updated_at?: string | null;
        };
      };
      sheets: {
        Row: {
          book_id: number | null;
          created_at: string | null;
          description: string | null;
          id: number;
          name: string | null;
          updated_at: string | null;
        };
        Insert: {
          book_id?: number | null;
          created_at?: string | null;
          description?: string | null;
          id?: number;
          name?: string | null;
          updated_at?: string | null;
        };
        Update: {
          book_id?: number | null;
          created_at?: string | null;
          description?: string | null;
          id?: number;
          name?: string | null;
          updated_at?: string | null;
        };
      };
      translations: {
        Row: {
          copies: Json | null;
          created_at: string | null;
          id: number;
          key: string | null;
          sheet_id: number | null;
          updated_at: string | null;
        };
        Insert: {
          copies?: Json | null;
          created_at?: string | null;
          id?: number;
          key?: string | null;
          sheet_id?: number | null;
          updated_at?: string | null;
        };
        Update: {
          copies?: Json | null;
          created_at?: string | null;
          id?: number;
          key?: string | null;
          sheet_id?: number | null;
          updated_at?: string | null;
        };
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
}

export type Book = Database["public"]["Tables"]["books"]["Row"];
export type Sheet = Database["public"]["Tables"]["sheets"]["Row"];
export type Translation = Database["public"]["Tables"]["translations"]["Row"];
export type DBError = PostgrestError | null;
