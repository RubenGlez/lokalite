import type { NextApiRequest, NextApiResponse } from "next";
import { Project } from ".";

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Project>
) {
  if (req.method === "GET") {
    res.status(200).json({
      id: "project_id_1",
      name: "landing page",
      description: "translations for the landing page",
      langs: ["es", "en", "it"],
      defaultLang: "en",
      book: ["sheet_id_1"],
    });
  }
}
