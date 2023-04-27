import { Translation } from "@/lib/database.types";
import { fetcher } from "@/lib/fetcher";
import { UpdateTranslationPayload } from "@/lib/queries/updateTranslation";
import { useState } from "react";

interface UseUpdateTranslationsProps {
  successCallback?: () => void;
  errorCallback?: () => void;
}

export const useUpdateTranslations = ({
  successCallback,
  errorCallback,
}: UseUpdateTranslationsProps) => {
  const [updaterState, setUpdaterState] = useState<{
    error: string | undefined;
    isLoading: boolean;
  }>({
    error: undefined,
    isLoading: false,
  });

  const updateTranslation = async (payload: UpdateTranslationPayload) => {
    setUpdaterState((prev) => ({ ...prev, isLoading: true }));
    try {
      await fetcher.update<UpdateTranslationPayload, Translation[]>(
        "/api/translations",
        payload
      );
      setUpdaterState({
        error: undefined,
        isLoading: false,
      });
      successCallback?.();
    } catch (error) {
      setUpdaterState({
        error: "Something went wrong",
        isLoading: false,
      });
      errorCallback?.();
    }
  };

  return {
    error: updaterState.error,
    isLoading: updaterState.isLoading,
    updateTranslation,
  };
};
