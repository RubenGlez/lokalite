import Layout from "@/components/Layout";
import Table from "@/components/Table";
import { useFetch } from "@/hooks/useFetch";
import ListBox from "@/components/ListBox";
import { useRouter } from "next/router";
import { Book } from "./api/book";
import { useState } from "react";
import Text from "@/components/Text";

const getHeaderCells = (
  langs: string[] | undefined = [],
  defaultLang: string | undefined = ""
) => {
  const headerCells = [
    { label: "key" },
    { label: defaultLang, isDefault: true },
    ...langs.map((l) => ({ label: l })),
  ];
  return headerCells;
};

export default function BookDetails() {
  const router = useRouter();
  const { bookId } = router.query;
  const { data, isLoading } = useFetch<Book>(`/api/book/${bookId}`);
  const options = data?.sheetsInfo.map(({ id, name }) => ({
    value: id,
    label: name,
  }));
  const [selected, setSelected] = useState(options?.[0]?.value ?? "");
  const handleChange = (val: string) => {
    setSelected(val);
  };

  const onChange = () => {};
  const headerCells = getHeaderCells(data?.langs, data?.defaultLang);

  if (isLoading) {
    return <Text>Loading...</Text>;
  }

  return (
    <Layout title="Example">
      <div className="absolute top-0 right-0 w-64 pt-2 pr-4">
        <ListBox
          options={options}
          handleChange={handleChange}
          value={selected}
          placeholder="Selecciona una hoja"
        />
      </div>
      <div className="overflow-x-auto">
        <Table
          headerCells={headerCells}
          onChange={onChange}
          sheetId={selected}
        />
      </div>
    </Layout>
  );
}
