import { Translation } from "@/lib/database.types";
import { fetcher } from "@/lib/fetcher";
import { useCallback, useState } from "react";

interface UseGetTranslationProps {
  successCallback?: () => void;
  errorCallback?: () => void;
}

export const useGetTranslation = ({
  successCallback,
  errorCallback,
}: UseGetTranslationProps) => {
  const [getterState, setGetterState] = useState<{
    error: string | undefined;
    data: Translation[];
    isLoading: boolean;
  }>({
    error: undefined,
    data: [],
    isLoading: false,
  });

  const getTranslation = useCallback(
    async (id: Translation["id"]) => {
      setGetterState((prev) => ({ ...prev, isLoading: true }));
      try {
        const response = await fetcher.get<Translation[]>(
          `/api/translations/${id}`
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
    },
    [errorCallback, successCallback]
  );

  return {
    translation: getterState.data?.[0],
    error: getterState.error,
    isLoading: getterState.isLoading,
    getTranslation,
  };
};
