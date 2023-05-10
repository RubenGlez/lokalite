import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import Text from "@/components/Text";
import SheetForm, { SheetFormData } from "@/partials/SheetForm";
import getSheetById from "@/lib/queries/getSheetById";
import { Sheet } from "@/lib/database.types";
import updateSheet from "@/lib/queries/updateSheet";
import { useNavigation } from "@/hooks/useNavigation";

interface EditSheetPageProps {
  sheet: Sheet;
}

interface PageContext {
  query: {
    sheetId: string;
  };
}

export default function EditSheetPage({ sheet }: EditSheetPageProps) {
  const { goTo } = useNavigation();
  const handleSubmit = async (form: SheetFormData) => {
    const { status } = await updateSheet({ ...form, id: sheet.id });
    if (status === HTTP_STATUS.UPDATED) {
      goTo("readBook", { bookId: sheet.book_id });
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

export async function getServerSideProps(context: PageContext) {
  const { sheetId } = context.query;
  const { data: sheetsData } = await getSheetById(Number(sheetId));

  return {
    props: {
      sheet: sheetsData?.[0],
    },
  };
}
