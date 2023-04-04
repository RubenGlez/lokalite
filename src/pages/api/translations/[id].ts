import updateTranslation from "@/lib/queries/updateTranslation";
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query;

  if (req.method === "PUT") {
    const { data, error } = await updateTranslation({
      id: Number(id),
      key: req.body.key,
      copies: req.body.copies,
    });
    if (error) {
      res.status(500).json({ error });
    } else {
      res.status(200).json(data);
    }
  } else {
    // Método no admitido
    res.setHeader("Allow", ["PUT"]);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}
