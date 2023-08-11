import type { NextApiRequest, NextApiResponse } from "next";

export type Example = {
  id: string;
  name: string;
};

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<Example>
) {
  if (req.method === "GET") {
    res.status(200).json({
      id: "example_id_1",
      name: "Example 1",
    });
  }
}
