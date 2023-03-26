import type { NextApiRequest, NextApiResponse } from "next";

export type Project = {
  id: string;
  name: string;
  description: string;
  bookId: string;
};

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Project[]>
) {
  if (req.method === "GET") {
    res.status(200).json([
      {
        id: "project_id_1",
        name: "landing page",
        description: "translations for the landing page",
        bookId: "book_id_1",
      },
      {
        id: "project_id_2",
        name: "mobile app",
        description: "translations for the mobile app",
        bookId: "book_id_2",
      },
    ]);
  }
}
