import { Translation } from "@/lib/database.types";
import useSWRMutation from "swr/mutation";

interface UseUpdateTranslationProps {
  translationId: Translation["id"];
}

async function updateTranslation(url: string, _options: any) {
  await fetch(url, {
    method: "POST",
  });
}

export const useUpdateTranslation = ({
  translationId,
}: UseUpdateTranslationProps) => {
  const { data, error, isMutating, reset, trigger } = useSWRMutation(
    `/api/translations/${translationId}`,
    updateTranslation
  );
  return { data, error, isMutating, reset, trigger };
};
