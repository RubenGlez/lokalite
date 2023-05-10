import { Routes, routes } from "@/constants/routes";
import { useRouter } from "next/router";

const getFinalRoute = (
  route: string,
  queryParams: Record<string, string | number | null | undefined>
) => {
  let finalRoute = `${route}`;
  Object.keys(queryParams).forEach((key) => {
    finalRoute = finalRoute.replace(`[${key}]`, `${queryParams[key]}`);
  });
  return finalRoute;
};

export const useNavigation = () => {
  const router = useRouter();

  const goTo = (
    routeKey: Routes,
    queryParams?: Record<string, string | number | null | undefined>
  ) => {
    const route = routes[routeKey].href;
    const finalRoute = queryParams ? getFinalRoute(route, queryParams) : route;
    router.push(finalRoute);
  };

  const goBack = router.back;

  return { goTo, goBack };
};
