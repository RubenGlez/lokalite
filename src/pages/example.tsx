import Layout from "@/components/Layout";
import Table from "@/components/Table";

export default function Example() {
  const onChange = () => {};
  const rows = [
    {
      cells: [
        { value: "page.section.component.part" },
        { value: "hello world" },
        { value: "hola mundo" },
        { value: "hola mundo" },
        { value: "hola mundo" },
        { value: "hola mundo" },
        { value: "hola mundo" },
        { value: "hola mundo" },
      ],
    },
  ];
  const headerCells = [
    { label: "key" },
    { label: "es (default)" },
    { label: "en" },
    { label: "it" },
    { label: "fr" },
    { label: "pt" },
    { label: "ru" },
    { label: "de" },
  ];

  return (
    <Layout title="Example">
      <div className="px-4 py-8">
        <Table headerCells={headerCells} rows={rows} onChange={onChange} />
      </div>
    </Layout>
  );
}
