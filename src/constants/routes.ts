export const routes = {
  home: {
    label: "Lokalite",
    href: "/",
  },
  // books
  books: {
    label: "Books",
    href: "/books",
  },
  createBook: {
    label: "Create book",
    href: "/books/create",
  },
  readBook: {
    label: "Book details",
    href: "/books/[bookId]",
  },
  updateBook: {
    label: "Edit book",
    href: "/books/[bookId]/edit",
  },
  deleteBook: {
    label: "Delete book",
    href: "/books/[bookId]/delete",
  },
  // sheets
  sheets: {
    label: "Sheets list",
    href: "/books/[bookId]/sheets",
  },
  createSheet: {
    label: "Create sheet",
    href: "/books/[bookId]/sheets/create",
  },
  readSheet: {
    label: "Sheet details",
    href: "/books/[bookId]/sheets/[sheetId]",
  },
  updateSheet: {
    label: "Update sheet",
    href: "/books/[bookId]/sheets/[sheetId]/edit",
  },
  deleteSheet: {
    label: "Delete sheet",
    href: "/books/[bookId]/sheets/[sheetId]/delete",
  },
  // sandbox
  sandbox: {
    label: "Sandbox",
    href: "/sandbox",
  },
};

export type Routes = keyof typeof routes;
