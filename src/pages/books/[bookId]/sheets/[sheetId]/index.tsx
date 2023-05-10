import Layout from "@/components/Layout";
import ListBox from "@/components/ListBox";
import Dropdown from "@/components/Dropdown";
import {
  PencilSquareIcon,
  TrashIcon,
  DocumentPlusIcon,
  DocumentTextIcon,
} from "@heroicons/react/24/outline";
import getBookById from "@/lib/queries/getBookById";
import getSheetsByBookId from "@/lib/queries/getSheetsByBookId";
import Text from "@/components/Text";
import BookSheet from "@/partials/BookSheet";
import { useAppContext } from "@/contexts/AppContext";
import { useNavigation } from "@/hooks/useNavigation";

interface PageContext {
  query: {
    bookId: string;
    sheetId: string;
  };
}

type PageProps = Awaited<ReturnType<typeof getServerSideProps>>["props"];

export default function BookDetails({ book, sheets, sheetId }: PageProps) {
  const { isLoadingGettingTranslations, isLoadingUpdatingTranslations } =
    useAppContext();
  const { goTo } = useNavigation();
  const settingsItems = [
    {
      label: "Edit book",
      Icon: PencilSquareIcon,
      onClick: () => {
        goTo("updateBook", { bookId: book?.id });
      },
    },
    {
      label: "Delete book",
      Icon: TrashIcon,
      onClick: () => {
        alert("Delete book not implemented");
      },
    },
    {
      label: "Add new sheet",
      Icon: DocumentPlusIcon,
      onClick: () => {
        goTo("createSheet", { bookId: book?.id });
      },
    },
    {
      label: "Edit sheet",
      Icon: DocumentTextIcon,
      onClick: () => {
        goTo("updateSheet", { bookId: book?.id, sheetId });
      },
    },
  ];
  const sheetOpts = sheets.map((sheet) => ({
    value: sheet.id,
    label: sheet.name ?? "",
  }));
  const handleChangeSheet = (val: string | number) => {
    goTo("readSheet", { bookId: book?.id, sheetId: val });
  };
  const handleCreateSheet = () => {
    goTo("createSheet", { bookId: book?.id });
  };

  return (
    <Layout>
      <div className="absolute top-0 right-0 pr-4 flex gap-x-4 h-12 flex items-center">
        {isLoadingGettingTranslations && (
          <Text size="sm">Obteniendo datos...</Text>
        )}
        {isLoadingUpdatingTranslations && <Text size="sm">Guardando...</Text>}
        <ListBox
          options={sheetOpts}
          handleChange={handleChangeSheet}
          defaultValue={sheetId}
          placeholder="Selecciona una hoja"
          className="w-48"
        />
        <Dropdown items={settingsItems} placeholder={"Settings"} />
      </div>
      <div className="h-full w-full">
        <BookSheet
          languages={book?.languages ?? []}
          defaultLanguage={book?.default_language ?? ""}
          sheetId={sheetId}
        />
      </div>
    </Layout>
  );
}

export async function getServerSideProps(context: PageContext) {
  const { bookId, sheetId } = context.query;
  const { data: bookData } = await getBookById(Number(bookId));
  const { data: sheetsData } = await getSheetsByBookId(Number(bookId));

  return {
    props: {
      book: bookData?.[0],
      sheets: sheetsData ?? [],
      sheetId: Number(sheetId),
    },
  };
}
