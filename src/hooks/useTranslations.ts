import { Translation } from "@/lib/database.types";
import { fetcher } from "@/lib/fetcher";
import { UpdateTranslationPayload } from "@/lib/queries/updateTranslation";
import { useEffect, useState } from "react";

interface UseTransProps {
  sheetId?: number;
}

export const useTranslations = ({ sheetId }: UseTransProps) => {
  const [getterState, setGetterState] = useState<{
    error: string | undefined;
    data: Translation[];
    isLoading: boolean;
  }>({
    error: undefined,
    data: [],
    isLoading: false,
  });
  const [updaterState, setUpdaterState] = useState<{
    error: string | undefined;
    isLoading: boolean;
  }>({
    error: undefined,
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
    } catch (error) {
      setGetterState((prev) => ({
        ...prev,
        error: "Something went wrong",
        isLoading: false,
      }));
    }
  };

  const updateTranslation = async (payload: UpdateTranslationPayload) => {
    setUpdaterState((prev) => ({ ...prev, isLoading: true }));
    try {
      await fetcher.update<UpdateTranslationPayload, Translation>(
        "/api/translations",
        payload
      );
      setUpdaterState((prev) => ({
        ...prev,
        error: undefined,
        isLoading: false,
      }));
    } catch (error) {
      setUpdaterState((prev) => ({
        ...prev,
        error: "Something went wrong",
        isLoading: false,
      }));
    }
  };

  useEffect(() => {
    if (sheetId) {
      getTranslations(sheetId);
    }
  }, [sheetId]);

  return {
    translations: getterState.data,
    getterError: getterState.error,
    getterIsLoading: getterState.isLoading,
    updaterError: updaterState.error,
    updaterIsLoading: updaterState.isLoading,
    updateTranslation,
  };
};
