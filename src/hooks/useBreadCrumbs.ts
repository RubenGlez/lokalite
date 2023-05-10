import { useRouter } from "next/router";

const getBreadCrumbs = (pathname: string) => {
  switch (pathname) {
    case "/books": {
      return [
        {
          label: "Lokalite",
          link: "/",
        },
        {
          label: "books",
        },
      ];
    }
    case "/books/[id]": {
      return [
        {
          label: "Lokalite",
          link: "/",
        },
        {
          label: "Books",
          link: "/books",
        },
        {
          label: "[id]",
        },
      ];
    }
    case "/books/edit": {
      return [
        {
          label: "Lokalite",
          link: "/",
        },
        {
          label: "Books",
          link: "/books",
        },
        {
          label: "Edit",
        },
      ];
    }
    case "/books/create": {
      return [
        {
          label: "Lokalite",
          link: "/",
        },
        {
          label: "Books",
          link: "/books",
        },
        {
          label: "Create",
        },
      ];
    }
    case "/sheets/create": {
      return [
        {
          label: "Lokalite",
          link: "/",
        },
        {
          label: "Sheets",
          link: "/sheets",
        },
        {
          label: "Create",
        },
      ];
    }
    case "/sheets/edit": {
      return [
        {
          label: "Lokalite",
          link: "/",
        },
        {
          label: "Sheets",
          link: "/sheets",
        },
        {
          label: "Edit",
        },
      ];
    }
    default: {
      return [
        {
          label: "Lokalite",
        },
      ];
    }
  }
};

export const useBreadcrumbs = () => {
  const { pathname } = useRouter();
  const breadcrumbs = getBreadCrumbs(pathname);

  return breadcrumbs;
};
