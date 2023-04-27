import { Translation } from "@/lib/database.types";
import { fetcher } from "@/lib/fetcher";
import { CreateTranslationsPayload } from "@/lib/queries/createTranslations";
import { useState } from "react";

interface UseCreateTranslationsProps {
  successCallback?: () => void;
  errorCallback?: () => void;
}

export const useCreateTranslations = ({
  successCallback,
  errorCallback,
}: UseCreateTranslationsProps) => {
  const [creatorState, setCreatorState] = useState<{
    error: string | undefined;
    isLoading: boolean;
  }>({
    error: undefined,
    isLoading: false,
  });

  const createTranslations = async (translations: Translation[]) => {
    setCreatorState((prev) => ({ ...prev, isLoading: true }));
    try {
      await fetcher.post<CreateTranslationsPayload, Translation[]>(
        "/api/translations",
        { translations }
      );
      setCreatorState({
        error: undefined,
        isLoading: false,
      });
      successCallback?.();
    } catch (error) {
      setCreatorState({
        error: "Something went wrong",
        isLoading: false,
      });
      errorCallback?.();
    }
  };

  return {
    error: creatorState.error,
    isLoading: creatorState.isLoading,
    createTranslations,
  };
};
