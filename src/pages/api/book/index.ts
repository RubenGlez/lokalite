import type { NextApiRequest, NextApiResponse } from "next";
import { Sheet } from "../sheet";

type SheetInfo = {
  id: string;
  name: string;
};

export type Book = {
  id: string;
  name: string;
  description: string;
  langs: string[];
  defaultLang: string;
  sheetsInfo: SheetInfo[];
};

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Book[]>
) {
  if (req.method === "GET") {
    res.status(200).json([
      {
        id: "book_id_1",
        name: "Application 1",
        description: "Translations for Application 1",
        langs: ["es", "it", "pt", "ru", "de", "us"],
        defaultLang: "en",
        sheetsInfo: [
          { id: "book_id_1_sheet_id_1", name: "Landing page" },
          { id: "book_id_1_sheet_id_2", name: "Mobile app 1" },
        ],
      },
      {
        id: "book_id_2",
        name: "Application 2",
        description: "Translations for Application 2",
        langs: ["en", "it", "pt", "ru", "de", "us"],
        defaultLang: "es",
        sheetsInfo: [
          { id: "book_id_1_sheet_id_1", name: "Landing page" },
          { id: "book_id_1_sheet_id_2", name: "Mobile app 1" },
        ],
      },
    ]);
  }
}
