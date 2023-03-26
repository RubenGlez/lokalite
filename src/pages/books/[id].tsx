import Layout from "@/components/Layout";
import Table from "@/components/Table";
import { useFetch } from "@/hooks/useFetch";
import ListBox from "@/components/ListBox";
import { useRouter } from "next/router";
import { Book } from "../api/book";
import { useState } from "react";
import Text from "@/components/Text";
import Dropdown from "@/components/Dropdown";
import { PencilSquareIcon, TrashIcon } from "@heroicons/react/24/outline";

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
  const { id } = router.query;
  const { data, isLoading } = useFetch<Book>(`/api/book/${id}`);
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
      <div className="absolute top-0 right-0 pt-2 pr-4 flex gap-x-4">
        <ListBox
          options={options}
          handleChange={handleChange}
          value={selected}
          placeholder="Selecciona una hoja"
        />
        <Dropdown
          items={[
            {
              label: "Edit book",
              Icon: PencilSquareIcon,
              onClick: () => {},
            },
            {
              label: "Delete book",
              Icon: TrashIcon,
              onClick: () => {},
            },
          ]}
          placeholder={"Settings"}
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
