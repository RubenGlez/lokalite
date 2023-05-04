import { Translation } from "@/lib/database.types";
import { fetcher } from "@/lib/fetcher";
import { useCallback, useState } from "react";

interface UseGetTranslationsProps {
  successCallback?: () => void;
  errorCallback?: () => void;
}

export const useGetTranslations = ({
  successCallback,
  errorCallback,
}: UseGetTranslationsProps) => {
  const [getterState, setGetterState] = useState<{
    error: string | undefined;
    data: Translation[];
    isLoading: boolean;
  }>({
    error: undefined,
    data: [],
    isLoading: false,
  });

  const getTranslations = async (sheetId: Translation["sheet_id"]) => {
    setGetterState((prev) => ({ ...prev, isLoading: true }));
    try {
      const response = await fetcher.get<Translation[]>(
        `/api/translations?sheetId=${sheetId}`
      );
      setGetterState({
        error: undefined,
        data: response,
        isLoading: false,
      });
      successCallback?.();
    } catch (error) {
      setGetterState((prev) => ({
        ...prev,
        error: "Something went wrong",
        isLoading: false,
      }));
      errorCallback?.();
    }
  };

  return {
    translations: getterState.data,
    error: getterState.error,
    isLoading: getterState.isLoading,
    getTranslations,
  };
};
