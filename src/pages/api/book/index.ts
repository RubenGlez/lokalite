import type { NextApiRequest, NextApiResponse } from "next";
import { Sheet } from "../sheet";

type SheetInfo = {
  id: string;
  name: string;
};

export type Book = {
  id: string;
  langs: string[];
  defaultLang: string;
  sheetsInfo: SheetInfo[];
};

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Sheet[]>
) {
  // Nothing here
}
