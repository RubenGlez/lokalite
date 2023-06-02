import { useRouter } from "next/router";
import { routes } from "@/constants/routes";
import { useNavigation } from "./useNavigation";
import { ParsedUrlQuery } from "querystring";

interface GetBreadCrumbsProps {
  pathname: string;
  query: ParsedUrlQuery;
  getRoute: ReturnType<typeof useNavigation>["getRoute"];
}

const getBreadCrumbs = ({ pathname, query, getRoute }: GetBreadCrumbsProps) => {
  const parts = pathname.split("/").slice(1);
  const breadcrumbs = parts.map((_, index) => {
    const path = `/${parts.slice(0, index + 1).join("/")}`;
    const routeName = Object.keys(routes).find((key) => {
      return routes[key as keyof typeof routes]?.href === path;
    });
    const href = getRoute(
      routeName as keyof typeof routes,
      query as Record<string, string | number | null | undefined>
    );
    return {
      ...routes[routeName as keyof typeof routes],
      href,
    };
  });
  return breadcrumbs;
};

export const useBreadcrumbs = () => {
  const { pathname, query } = useRouter();
  const { getRoute } = useNavigation();
  const breadcrumbs = getBreadCrumbs({ pathname, query, getRoute });

  return breadcrumbs;
};
