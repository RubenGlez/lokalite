import Layout from "@/partials/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import createSheet from "@/lib/queries/createSheet";
import { useRouter } from "next/router";
import Text from "@/components/Text";
import SheetForm, { SheetFormData } from "@/partials/SheetForm";
import { useNavigation } from "@/hooks/useNavigation";

export default function CreateSheetPage() {
  const router = useRouter();
  const { goTo } = useNavigation();
  const handleSubmit = async (form: SheetFormData) => {
    const bookId = Number(router.query.bookId);
    const { status } = await createSheet({ ...form, book_id: bookId });
    if (status === HTTP_STATUS.CREATED) {
      goTo("readBook", { bookId });
    }
  };

  return (
    <Layout>
      <div className="p-8 w-full">
        <Text as="p" size="xs" color="secondary" className="mb-6">
          {"CREAR HOJA"}
        </Text>
        <SheetForm handleSubmit={handleSubmit} />
      </div>
    </Layout>
  );
}
