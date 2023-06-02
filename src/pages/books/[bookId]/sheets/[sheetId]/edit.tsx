import Layout from "@/partials/Layout";
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
      <div className="p-8 w-full">
        <Text as="p" size="xs" color="secondary" className="mb-6">
          {"DETALES DE LA HOJA"}
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
