import type { NextApiRequest, NextApiResponse } from "next";
import { Sheet } from ".";

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Sheet>
) {
  if (req.method === "GET") {
    res.status(200).json({
      id: "sheet_id_1",
      name: "landing page",
      description: "translations for the landing page",
      locales: [
        {
          key: "example.key.1",
          es: "loren ipsum dolor sit amet",
          en: "loren ipsum dolor sit amet",
          it: "loren ipsum dolor sit amet",
          pt: "loren ipsum dolor sit amet",
          ru: "loren ipsum dolor sit amet",
          de: "loren ipsum dolor sit amet",
          us: "loren ipsum dolor sit amet",
        },
        {
          key: "example.key.2",
          es: "loren ipsum dolor sit amet",
          en: "loren ipsum dolor sit amet",
          it: "loren ipsum dolor sit amet",
          pt: "loren ipsum dolor sit amet",
          ru: "loren ipsum dolor sit amet",
          de: "loren ipsum dolor sit amet",
          us: "loren ipsum dolor sit amet",
        },
        {
          key: "example.key.3",
          es: "loren ipsum dolor sit amet",
          en: "loren ipsum dolor sit amet",
          it: "loren ipsum dolor sit amet",
          pt: "loren ipsum dolor sit amet",
          ru: "loren ipsum dolor sit amet",
          de: "loren ipsum dolor sit amet",
          us: "loren ipsum dolor sit amet",
        },
      ],
    });
  }
}
