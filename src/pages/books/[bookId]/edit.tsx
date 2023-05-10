import Layout from "@/components/Layout";
import { HTTP_STATUS } from "@/constants/httpStatus";
import BookForm from "@/partials/BookForm";
import Text from "@/components/Text";
import updateBook, { UpdateBookBody } from "@/lib/queries/updateBook";
import { CreateBookBody } from "@/lib/queries/createBook";
import getBookById from "@/lib/queries/getBookById";
import { Book } from "@/lib/database.types";
import { useNavigation } from "@/hooks/useNavigation";

interface EditBookPageProps {
  book: Book;
}

interface PageContext {
  query: {
    bookId: string;
  };
}

export default function EditBookPage({ book }: EditBookPageProps) {
  const { goTo } = useNavigation();
  const handleSubmit = async (form: UpdateBookBody | CreateBookBody) => {
    const updateForm = form as UpdateBookBody;
    const { status } = await updateBook(updateForm);
    if (status === HTTP_STATUS.CREATED) {
      goTo("books");
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

export async function getServerSideProps(context: PageContext) {
  const { bookId } = context.query;
  const { data: bookData } = await getBookById(Number(bookId));

  return {
    props: {
      book: bookData?.[0],
    },
  };
}
