import { Translation } from "@/lib/database.types";
import { useCreateTranslations } from "./useCreateTranslations";
import { useGetTranslations } from "./useGetTranslations";
import { useUpdateTranslations } from "./useUpdateTranslation";
import { useEffect, useState } from "react";

interface UseTranslationsProps {
  sheetId: Translation["sheet_id"];
}
export const useTranslations = ({ sheetId }: UseTranslationsProps) => {
  const [createAndGetState, setCreateAndGetState] = useState<{
    error: string | undefined;
    isLoading: boolean;
  }>({
    error: undefined,
    isLoading: false,
  });

  const getSuccessCallback = () => {
    setCreateAndGetState({ error: undefined, isLoading: false });
  };
  const getErrorCallback = () => {
    setCreateAndGetState({ error: "Something went wrong", isLoading: false });
  };
  const { error, getTranslations, isLoading, translations } =
    useGetTranslations({
      successCallback: getSuccessCallback,
      errorCallback: getErrorCallback,
    });

  const {
    error: errorUpdating,
    isLoading: isUpdating,
    updateTranslation,
  } = useUpdateTranslations({});

  const createSuccessCallback = () => {
    getTranslations(sheetId);
  };
  const createErrorCallback = () => {
    setCreateAndGetState({ error: "Something went wrong", isLoading: false });
  };
  const { createTranslations } = useCreateTranslations({
    successCallback: createSuccessCallback,
    errorCallback: createErrorCallback,
  });

  const createAndGet = (trans: Translation[]) => {
    setCreateAndGetState((prev) => ({ ...prev, isLoading: true }));
    createTranslations(trans);
  };

  useEffect(() => {
    if (sheetId) {
      getTranslations(sheetId);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sheetId]);

  return {
    // get
    error,
    getTranslations,
    isLoading,
    translations,
    // update
    errorUpdating,
    isUpdating,
    updateTranslation,
    // create
    createAndGet,
    isCreatingAndGetting: createAndGetState.isLoading,
    errorCreatingAndGetting: createAndGetState.error,
  };
};
