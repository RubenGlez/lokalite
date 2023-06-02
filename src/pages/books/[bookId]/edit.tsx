import Layout from "@/partials/Layout";
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
      <div className="p-8 w-full">
        <Text as="p" size="xs" color="secondary" className="mb-6">
          {"EDITAR LIBRO"}
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
