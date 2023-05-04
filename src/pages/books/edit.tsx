import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import BookForm from "@/partials/BookForm";
import { useRouter } from "next/router";
import Text from "@/components/Text";
import updateBook, { UpdateBookBody } from "@/lib/queries/updateBook";
import { CreateBookBody } from "@/lib/queries/createBook";
import getBookById from "@/lib/queries/getBookById";
import { Book } from "@/lib/database.types";

interface EditBookPageProps {
  book: Book;
}

export default function EditBookPage({ book }: EditBookPageProps) {
  const router = useRouter();
  const handleSubmit = async (form: UpdateBookBody | CreateBookBody) => {
    const updateForm = form as UpdateBookBody;
    const { status } = await updateBook(updateForm);
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
        <BookForm handleSubmit={handleSubmit} initialData={book} />
      </div>
    </Layout>
  );
}

export async function getServerSideProps(context: { query: { id: string } }) {
  const { id } = context.query;
  const { data: bookData } = await getBookById(Number(id));

  return {
    props: {
      book: bookData?.[0],
    },
  };
}
