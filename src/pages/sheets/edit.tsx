import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import createSheet from "@/lib/queries/createSheet";
import { useRouter } from "next/router";
import Text from "@/components/Text";
import SheetForm, { SheetFormData } from "@/partials/SheetForm";
import getSheetById from "@/lib/queries/getSheetById";
import { Sheet } from "@/lib/database.types";

interface EditSheetPageProps {
  sheet: Sheet;
}

export default function EditSheetPage({ sheet }: EditSheetPageProps) {
  const router = useRouter();
  const handleSubmit = async (form: SheetFormData) => {
    const { status } = await createSheet({ ...form, book_id: sheet.id });
    if (status === HTTP_STATUS.CREATED) {
      router.push(`/books/${sheet.id}`);
    }
  };

  return (
    <Layout>
      <div className="px-8 py-8">
        <Text as="h3" className="mb-4" size="lg">
          Crear hoja
        </Text>
        <SheetForm handleSubmit={handleSubmit} initialData={sheet} />
      </div>
    </Layout>
  );
}

export async function getServerSideProps(context: { query: { id: string } }) {
  const { id } = context.query;
  const { data: sheetsData } = await getSheetById(Number(id));

  return {
    props: {
      sheet: sheetsData?.[0],
    },
  };
}
