import { Translation } from "@/lib/database.types";
import { useFetch } from "./useFetch";

interface UseGetTranslationProps {
  translationId?: number;
}

export const useGetTranslation = ({
  translationId,
}: UseGetTranslationProps) => {
  const { error, data, isLoading, isValidating, mutate } = useFetch<
    Translation[]
  >(`/api/translations/${translationId}`);

  return { error, data, isLoading, isValidating, mutate };
};
