import Layout from "@/components/Layout";
import getBookById from "@/lib/queries/getBookById";
import getSheetsByBookId from "@/lib/queries/getSheetsByBookId";
import Text from "@/components/Text";
import { useEffect } from "react";
import { useNavigation } from "@/hooks/useNavigation";

interface PageContext {
  query: {
    bookId: string;
  };
}

type PageProps = Awaited<ReturnType<typeof getServerSideProps>>["props"];

export default function BookDetails({ sheets }: PageProps) {
  const { goTo } = useNavigation();
  const firstSheet = sheets?.[0];

  useEffect(() => {
    if (!!firstSheet) {
      const { book_id: bookId, id: sheetId } = firstSheet;
      goTo("readSheet", { bookId, sheetId });
    }
  }, [firstSheet, goTo]);

  return (
    <Layout>
      <div className="p-8">
        {!!firstSheet ? (
          <Text size="sm">Loading...</Text>
        ) : (
          <Text size="sm">
            listado con las sheets del book y varias opciones
          </Text>
        )}
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
    },
  };
}
