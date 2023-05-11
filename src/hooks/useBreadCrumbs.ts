import { useRouter } from "next/router";
import { routes } from "@/constants/routes";

const getBreadCrumbs = (pathname: string) => {
  const parts = pathname.split("/").slice(1);
  const breadcrumbs = parts.map((_, index) => {
    const path = `/${parts.slice(0, index + 1).join("/")}`;
    const routeName = Object.keys(routes).find((key) => {
      return routes[key as keyof typeof routes]?.href === path;
    });
    return routes[routeName as keyof typeof routes];
  });
  return breadcrumbs;
};

export const useBreadcrumbs = () => {
  const { pathname } = useRouter();
  const breadcrumbs = getBreadCrumbs(pathname);

  return breadcrumbs;
};
