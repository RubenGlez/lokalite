import Layout from "@/partials/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import createBook, { CreateBookBody } from "@/lib/queries/createBook";
import BookForm from "@/partials/BookForm";
import Text from "@/components/Text";
import { useNavigation } from "@/hooks/useNavigation";

export default function CreateBookPage() {
  const { goTo } = useNavigation();
  const handleSubmit = async (form: CreateBookBody) => {
    const { status: createBookStatus } = await createBook({
      ...form,
    });
    if (createBookStatus === HTTP_STATUS.CREATED) {
      goTo("books");
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
