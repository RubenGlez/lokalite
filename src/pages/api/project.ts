import type { NextApiRequest, NextApiResponse } from "next";

type Project = {
  id: string;
  name: string;
  description: string;
  langs: string[];
  defaultLang: string;
  sheets: string[];
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
        langs: ["es", "en", "it"],
        defaultLang: "en",
        sheets: ["sheet_id_1"],
      },
      {
        id: "project_id_2",
        name: "mobile app",
        description: "translations for the mobile app",
        langs: ["es", "en", "fr", "pt"],
        defaultLang: "en",
        sheets: ["sheet_id_2", "sheet_id_3"],
      },
    ]);
  }
}
