import { AppContext, IAppContext } from "@/contexts/AppContext";
import { useContext } from "react";

export const useAppContext = (): IAppContext => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error("useAppContext must be used inside a AppContextProvider");
  }
  return context;
};
