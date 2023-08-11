import { fetcher } from "@/lib/fetcher";
import { useState } from "react";

interface UseTranslate {
  successCallback?: () => void;
  errorCallback?: () => void;
}

interface TranslatePayload {
  copy: string;
  inputLang: string;
  languages: string[];
}

interface TranslateResponse {
  result: string;
}

export const useTranslate = ({
  successCallback,
  errorCallback,
}: UseTranslate) => {
  const [requestState, setRequestState] = useState<{
    error: string | undefined;
    isLoading: boolean;
    data: string;
  }>({
    error: undefined,
    isLoading: false,
    data: "",
  });

  const translate = async (payload: TranslatePayload) => {
    setRequestState((prev) => ({ ...prev, isLoading: true }));
    try {
      const response = await fetcher.post<TranslatePayload, TranslateResponse>(
        "/api/gpt/translate",
        payload
      );
      setRequestState({
        error: undefined,
        isLoading: false,
        data: response.result,
      });
      successCallback?.();
    } catch (error) {
      setRequestState((prev) => ({
        ...prev,
        error: "Something went wrong",
        isLoading: false,
      }));
      errorCallback?.();
    }
  };

  return {
    error: requestState.error,
    isLoading: requestState.isLoading,
    data: requestState.data,
    translate,
  };
};
