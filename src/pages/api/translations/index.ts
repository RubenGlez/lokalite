import createTranslations from "@/lib/queries/createTranslations";
import getTranslationsBySheetId from "@/lib/queries/getTranslationsBySheetId";
import updateTranslation from "@/lib/queries/updateTranslation";
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { sheetId } = req.query;

  if (req.method === "GET") {
    const { data, error } = await getTranslationsBySheetId(Number(sheetId));
    if (error) {
      res.status(500).json({ error });
    } else {
      res.status(200).json(data);
    }
  } else if (req.method === "PUT") {
    const { data, error } = await updateTranslation(req.body);
    if (error) {
      res.status(500).json({ error });
    } else {
      res.status(200).json(data);
    }
  } else if (req.method === "POST") {
    const { data, error } = await createTranslations(req.body);
    if (error) {
      res.status(500).json({ error });
    } else {
      res.status(200).json(data);
    }
  } else {
    // Método no admitido
    res.setHeader("Allow", ["GET", "PUT", "POST"]);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}
