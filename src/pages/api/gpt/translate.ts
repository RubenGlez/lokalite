import { NextApiRequest, NextApiResponse } from "next";
import { Configuration, OpenAIApi } from "openai";

const configuration = new Configuration({
  apiKey: process.env.OPENAI_API_KEY,
});
const openai = new OpenAIApi(configuration);

function generatePrompt(copy: string, languages: string[], inputLang: string) {
  return `Act as a copywriter and expert translator.
    Translates the text provided, into all the languages indicated.
    Languages will be indicated as an ISO code.
    The text provided is written in ${inputLang} (ISO code).
    You must to return the result as a valid stringified JSON object.
    The keys of the JSON will be the ISO codes and the values will be the translations.
    For example if the text where: "hello", and the languages: "es, fr" the response would be: "{"es": "hola", "fr": "bonjour"}"
    - Text: ${copy}
    - Languages: ${languages.join(", ")}
    - The response:`;
}

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method === "POST") {
    if (!configuration.apiKey) {
      res.status(500).json({
        error: {
          message:
            "OpenAI API key not configured, please follow instructions in README.md",
        },
      });
      return;
    }

    const copy = req.body.copy || "";
    const inputLang = req.body.inputLang || "";
    const languages = req.body.languages || [];
    if (copy.trim().length === 0) {
      res.status(400).json({
        error: {
          message: "Please enter a valid copy text",
        },
      });
      return;
    }

    try {
      const completion = await openai.createCompletion({
        model: "text-davinci-003",
        prompt: generatePrompt(copy, languages, inputLang),
        temperature: 0.6,
        max_tokens: 256,
        stop: undefined,
        top_p: 1.0,
        frequency_penalty: 0,
        presence_penalty: 0,
      });
      res.status(200).json({
        result: JSON.parse(completion.data.choices[0].text?.trim() ?? ""),
      });
    } catch (error: any) {
      // Consider adjusting the error handling logic for your use case
      if (error.response) {
        console.error(error.response.status, error.response.data);
        res.status(error.response.status).json(error.response.data);
      } else {
        console.error(`Error with OpenAI API request: ${error.message}`);
        res.status(500).json({
          error: {
            message: "An error occurred during your request.",
          },
        });
      }
    }
  } else {
    // Método no admitido
    res.setHeader("Allow", ["POST"]);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}
