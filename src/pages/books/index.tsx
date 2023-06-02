import Card from "@/components/Card";
import Text from "@/components/Text";
import Layout from "@/partials/Layout";
import { useNavigation } from "@/hooks/useNavigation";
import { Book } from "@/lib/database.types";
import getAllBooks from "@/lib/queries/getAllBooks";

export interface BooksPageProps {
  books: Book[];
}

export default function BooksPage({ books }: BooksPageProps) {
  const { goTo } = useNavigation();
  const handleCardClick = (bookId: number) => () => {
    goTo("readBook", { bookId });
  };
  const handleCreateCardClick = () => {
    goTo("createBook");
  };

  return (
    <Layout>
      <div className="p-8">
        <Text as="p" size="xs" color="secondary" className="mb-6">
          {"LIBROS"}
        </Text>
        <div className="grid grid-flow-col gap-6">
          {books?.map((book) => (
            <Card
              key={book.id}
              title={book.name}
              subtitle={book.description}
              description={`[${book.default_language}] ${book.languages?.join(
                ", "
              )}`}
              onClick={handleCardClick(book.id)}
            />
          ))}
          <Card
            title="+ Crear libro"
            subtitle="Haz click para crear un nuevo libro"
            description="lets go!"
            onClick={handleCreateCardClick}
          />
        </div>
      </div>
    </Layout>
  );
}

export async function getServerSideProps() {
  const { data } = await getAllBooks();

  return {
    props: {
      books: data,
    },
  };
}
