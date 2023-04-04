import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import createBook, { CreateBookBody } from "@/lib/queries/createBook";
import BookForm from "@/partials/BookForm";
import { useRouter } from "next/router";
import Text from "@/components/Text";

export default function CreateBookPage() {
  const router = useRouter();
  const handleSubmit = async (form: CreateBookBody) => {
    const { status: createBookStatus } = await createBook({
      ...form,
    });
    if (createBookStatus === HTTP_STATUS.CREATED) {
      router.push("/books");
    }
  };

  return (
    <Layout>
      <div className="px-8 py-8">
        <Text as="h3" className="mb-4" size="lg">
          Crear libro
        </Text>
        <BookForm handleSubmit={handleSubmit} />
      </div>
    </Layout>
  );
}
