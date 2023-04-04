import { Translation } from "@/lib/database.types";
import { useFetch } from "./useFetch";
import { DEFAULT_ROW } from "@/partials/BookSheet/helpers";

interface UseTranslationsProps {
  sheetId?: number;
}

export const useTranslations = ({ sheetId }: UseTranslationsProps) => {
  const {
    data = [],
    error,
    isLoading,
    isValidating,
    mutate,
  } = useFetch<Translation[]>(
    sheetId ? `/api/translations?sheetId=${sheetId}` : ""
  );

  const translations = data.concat(DEFAULT_ROW);

  return {
    translations,
    error,
    isLoading,
    isValidating,
    mutate,
  };
};
