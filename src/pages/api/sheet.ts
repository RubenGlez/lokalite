import type { NextApiRequest, NextApiResponse } from "next";

type Locale = Record<string, string>;

type Sheet = {
  id: string;
  name: string;
  description: string;
  locales: Locale[];
};

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
          es: "hola mundo",
          en: "hello world",
          it: "ciao mondo",
        },
        {
          key: "example.key.2",
          es: "hola mundo 2",
          en: "hello world 2",
          it: "ciao mondo 2",
        },
        {
          key: "example.key.3",
          es: "hola mundo 3",
          en: "hello world 3",
          it: "ciao mondo 3",
        },
      ],
    });
  }
}
