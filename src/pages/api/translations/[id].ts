import getTranslationById from "@/lib/queries/getTranslationById";
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method === "GET") {
    const { id } = req.query;
    const { data, error } = await getTranslationById(Number(id));

    if (error) {
      res.status(500).json({ error });
    } else {
      res.status(200).json(data);
    }
  }
}
