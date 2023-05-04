import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import createSheet from "@/lib/queries/createSheet";
import { useRouter } from "next/router";
import Text from "@/components/Text";
import SheetForm, { SheetFormData } from "@/partials/SheetForm";

export default function CreateSheetPage() {
  const router = useRouter();
  const handleSubmit = async (form: SheetFormData) => {
    const bookId = Number(router.query.bookId);
    const { status } = await createSheet({ ...form, book_id: bookId });
    if (status === HTTP_STATUS.CREATED) {
      router.push(`/books/${bookId}`);
    }
  };

  return (
    <Layout>
      <div className="px-8 py-8">
        <Text as="h3" className="mb-4" size="lg">
          Crear hoja
        </Text>
        <SheetForm handleSubmit={handleSubmit} />
      </div>
    </Layout>
  );
}
