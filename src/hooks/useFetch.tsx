import useSWR, { SWRConfiguration } from "swr";

export const fetcher = (
  input: RequestInfo | URL,
  init?: RequestInit | undefined
) => fetch(input, init).then((res) => res.json());

export const useFetch = <T,>(endpoint: string, config?: SWRConfiguration) => {
  return useSWR<T, Error>(endpoint, fetcher, config);
};
