import Layout from "@/components/Layout";
import getSheetsByBookId from "@/lib/queries/getSheetsByBookId";
import Text from "@/components/Text";
import { useNavigation } from "@/hooks/useNavigation";
import Link from "next/link";
import Button from "@/components/Button";

interface PageContext {
  query: {
    bookId: string;
  };
}

type PageProps = Awaited<ReturnType<typeof getServerSideProps>>["props"];

export default function SheetsPage({ sheets, bookId }: PageProps) {
  const { getRoute, goTo } = useNavigation();
  const handleGoToCreateSheet = () => {
    goTo("createSheet", { bookId });
  };
  const handleGoToEditSheet = (sheetId: number) => () => {
    goTo("updateSheet", { bookId, sheetId });
  };
  const handleGoToDeleteSheet = (sheetId: number) => () => {
    goTo("deleteSheet", { bookId, sheetId });
  };
  const handleGoToUpdateBook = () => {
    goTo("updateBook", { bookId });
  };
  const handleGoToDeleteBook = () => {
    goTo("deleteBook", { bookId });
  };

  return (
    <Layout>
      <div className="p-8">
        <div className="py-8 flex gap-4">
          <Button text={"Editar libro"} onClick={handleGoToUpdateBook} />
          <Button text={"Borrar libro"} onClick={handleGoToDeleteBook} />
        </div>

        <div className="flex flex-col">
          {sheets.map((sheet) => (
            <div key={sheet.id} className="py-1">
              <Link
                href={getRoute("readSheet", {
                  bookId: sheet.book_id,
                  sheetId: sheet.id,
                })}
              >
                <Text>{sheet.name}</Text>
              </Link>
              <Button text={"editar"} onClick={handleGoToEditSheet(sheet.id)} />
              <Button
                text={"borrar"}
                onClick={handleGoToDeleteSheet(sheet.id)}
              />
            </div>
          ))}
        </div>
        <div className="py-8 flex gap-4">
          <Button text={"Crear hoja"} onClick={handleGoToCreateSheet} />
        </div>
      </div>
    </Layout>
  );
}

export async function getServerSideProps(context: PageContext) {
  const { bookId } = context.query;
  const { data: sheetsData } = await getSheetsByBookId(Number(bookId));

  return {
    props: {
      sheets: sheetsData || [],
      bookId,
    },
  };
}
