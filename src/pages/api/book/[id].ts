import type { NextApiRequest, NextApiResponse } from "next";
import { Book } from ".";

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Book>
) {
  if (req.method === "GET") {
    res.status(200).json({
      id: "book_id_1",
      name: "landing page",
      description: "translations for the landing page",
      langs: ["en", "es", "it", "pt", "ru", "de", "us"],
      defaultLang: "en",
      sheetsInfo: [
        { id: "sheet_id_1", name: "landing page" },
        { id: "sheet_id_2", name: "mobile app 1" },
      ],
    });
  }
}
