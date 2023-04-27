import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useCallback,
} from "react";

interface IAppState {
  isLoadingGettingTranslations: boolean;
  isLoadingUpdatingTranslations: boolean;
}

const initialState: IAppState = {
  isLoadingGettingTranslations: false,
  isLoadingUpdatingTranslations: false,
};

interface IAppContext {
  isLoadingGettingTranslations: boolean;
  isLoadingUpdatingTranslations: boolean;
  setIsLoadingGettingTranslations: (isLoading: boolean) => void;
  setIsLoadingUpdatingTranslations: (isLoading: boolean) => void;
}

const AppContext = createContext<IAppContext | undefined>(undefined);

export const useAppContext = (): IAppContext => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error("useAppContext must be used inside a AppContextProvider");
  }
  return context;
};

interface AppContextProviderProps {
  children: ReactNode;
}

export const AppContextProvider = ({
  children,
}: AppContextProviderProps): JSX.Element => {
  const [sharedState, setSharedState] = useState<IAppState>(initialState);

  const setIsLoadingGettingTranslations = useCallback((isLoading: boolean) => {
    setSharedState((prev) => ({
      ...prev,
      isLoadingGettingTranslations: isLoading,
    }));
  }, []);
  const setIsLoadingUpdatingTranslations = useCallback((isLoading: boolean) => {
    setSharedState((prev) => ({
      ...prev,
      isLoadingUpdatingTranslations: isLoading,
    }));
  }, []);

  const value = {
    ...sharedState,
    setIsLoadingGettingTranslations,
    setIsLoadingUpdatingTranslations,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
};
