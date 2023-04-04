import Layout from "@/components/Layout";
import ListBox from "@/components/ListBox";
import Dropdown from "@/components/Dropdown";
import { PencilSquareIcon, TrashIcon } from "@heroicons/react/24/outline";
import getBookById from "@/lib/queries/getBookById";
import { Book, Sheet } from "@/lib/database.types";
import { useRouter } from "next/router";
import getSheetsByBookId from "@/lib/queries/getSheetsByBookId";
import { useState } from "react";
import Text from "@/components/Text";
import Button from "@/components/Button";
import BookSheet from "@/partials/BookSheet";

export interface BooksPageProps {
  book: Book;
  sheets: Sheet[];
}

export default function BookDetails({ book, sheets = [] }: BooksPageProps) {
  const router = useRouter();
  const handleEditBook = () => {
    router.push(`/books/edit/${book.id}`);
  };
  const settingsItems = [
    {
      label: "Edit book",
      Icon: PencilSquareIcon,
      onClick: handleEditBook,
    },
    {
      label: "Delete book",
      Icon: TrashIcon,
      onClick: () => {},
    },
  ];
  const sheetOpts = sheets.map((sheet) => ({
    value: sheet.id,
    label: sheet.name ?? "",
  }));
  const [selectedSheetId, setSelectedSheetId] = useState(sheetOpts[0]?.value);
  const handleChangeSheet = (val: string | number) => {
    setSelectedSheetId(Number(val));
  };
  const handleCreateSheet = () => {
    router.push(`/sheets/create?bookId=${book.id}`);
  };

  return (
    <Layout>
      <div className="absolute top-0 right-0 pr-4 flex gap-x-4">
        <ListBox
          options={sheetOpts}
          handleChange={handleChangeSheet}
          defaultValue={selectedSheetId}
          placeholder="Selecciona una hoja"
          className="w-48"
        />
        <Dropdown items={settingsItems} placeholder={"Settings"} />
      </div>
      <div className="h-full w-full">
        {!!selectedSheetId ? (
          <BookSheet
            languages={book.languages}
            defaultLanguage={book.default_language}
            sheetId={selectedSheetId}
          />
        ) : (
          <div>
            <Text as="p">Libro vacío</Text>
            <Text as="p">Crea una hoja para empezar</Text>
            <Button text={"Nueva hoja"} onClick={handleCreateSheet} />
          </div>
        )}
      </div>
    </Layout>
  );
}

export async function getServerSideProps(context: { query: { id: string } }) {
  const { id } = context.query;
  const { data: bookData } = await getBookById(Number(id));
  const { data: sheetsData } = await getSheetsByBookId(Number(id));

  return {
    props: {
      book: bookData?.[0],
      sheets: sheetsData,
    },
  };
}