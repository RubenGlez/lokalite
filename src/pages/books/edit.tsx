import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import BookForm from "@/partials/BookForm";
import { useRouter } from "next/router";
import Text from "@/components/Text";
import updateBook, { UpdateBookBody } from "@/lib/queries/updateBook";

export default function EditBookPage() {
  const router = useRouter();
  const handleSubmit = async (form: UpdateBookBody) => {
    const { status } = await updateBook(form);
    if (status === HTTP_STATUS.CREATED) {
      router.push("/books");
    }
  };

  return (
    <Layout>
      <div className="px-8 py-8">
        <Text as="h3" className="mb-4" size="lg">
          Editar libro
        </Text>
        <BookForm handleSubmit={handleSubmit} />
      </div>
    </Layout>
  );
}
