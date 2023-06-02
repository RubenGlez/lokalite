import Layout from "@/partials/Layout";
import getSheetsByBookId from "@/lib/queries/getSheetsByBookId";
import Text from "@/components/Text";
import { useNavigation } from "@/hooks/useNavigation";
import Link from "next/link";
import Button from "@/components/Button";
import getBookById from "@/lib/queries/getBookById";
import { TrashIcon, PencilIcon } from "@heroicons/react/24/outline";

interface PageContext {
  query: {
    bookId: string;
  };
}

type PageProps = Awaited<ReturnType<typeof getServerSideProps>>["props"];

export default function BookDetails({ sheets, book }: PageProps) {
  const { getRoute, goTo } = useNavigation();
  const handleGoToCreateSheet = () => {
    goTo("createSheet", { bookId: book?.id });
  };
  const handleGoToEditSheet = (sheetId: number) => () => {
    goTo("updateSheet", { bookId: book?.id, sheetId });
  };
  const handleGoToDeleteSheet = (sheetId: number) => () => {
    goTo("deleteSheet", { bookId: book?.id, sheetId });
  };
  const handleGoToUpdateBook = () => {
    goTo("updateBook", { bookId: book?.id });
  };
  const handleGoToDeleteBook = () => {
    goTo("deleteBook", { bookId: book?.id });
  };

  return (
    <Layout>
      <div className="p-8 w-full">
        <Text as="p" size="xs" color="secondary" className="mb-6">
          {"DETALES DEL LIBRO"}
        </Text>
        <div className="pb-12">
          <Text as="h2" size="lg" className="mb-2">
            {book?.name}
          </Text>
          <Text as="p">{book?.description}</Text>
        </div>

        <Text as="p" size="xs" color="secondary" className="mb-6">
          {"HOJAS"}
        </Text>
        <div className="flex flex-col divide-y divide-slate-700 border border-slate-700 rounded-md">
          {sheets.map((sheet) => (
            <div
              key={sheet.id}
              className="px-4 py-2 flex flex-row gap-x-2 items-center"
            >
              <div className="flex-1">
                <Link
                  href={getRoute("readSheet", {
                    bookId: sheet.book_id,
                    sheetId: sheet.id,
                  })}
                >
                  <Text
                    size="sm"
                    color="secondary"
                    className="hover:text-slate-100"
                  >
                    {sheet.name}
                  </Text>
                </Link>
              </div>
              <div className="flex flex-row divide-x divide-slate-700">
                <div className="pr-4">
                  <PencilIcon
                    className="h-4 w-4 text-slate-400 hover:text-slate-100 cursor-pointer"
                    aria-hidden="true"
                    onClick={handleGoToEditSheet(sheet.id)}
                  />
                </div>
                <div className="pl-4">
                  <TrashIcon
                    className="h-4 w-4 text-slate-400 hover:text-slate-100 cursor-pointer"
                    aria-hidden="true"
                    onClick={handleGoToDeleteSheet(sheet.id)}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="pt-12 flex gap-4">
          <Button
            template="secondary"
            text={"Añadir nueva hoja"}
            onClick={handleGoToCreateSheet}
          />
          <Button text={"Editar libro"} onClick={handleGoToUpdateBook} />
          <Button
            text={"Borrar libro"}
            onClick={handleGoToDeleteBook}
            template="danger"
          />
        </div>
      </div>
    </Layout>
  );
}

export async function getServerSideProps(context: PageContext) {
  const { bookId } = context.query;
  const { data: sheetsData } = await getSheetsByBookId(Number(bookId));
  const { data: bookData } = await getBookById(Number(bookId));

  return {
    props: {
      sheets: sheetsData || [],
      book: bookData?.[0],
    },
  };
}
