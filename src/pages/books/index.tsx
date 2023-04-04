import Card from "@/components/Card";
import Layout from "@/components/Layout";
import { Book } from "@/lib/database.types";
import getAllBooks from "@/lib/queries/getAllBooks";
import { useRouter } from "next/router";

export interface BooksPageProps {
  books: Book[];
}

export default function BooksPage({ books }: BooksPageProps) {
  const router = useRouter();
  const handleCardClick = (bookId: number) => () => {
    router.push(`/books/${bookId}`);
  };
  const handleCreateCardClick = () => {
    router.push("/books/create");
  };

  return (
    <Layout>
      <div className="px-8 py-8">
        <div className="grid grid-cols-4 gap-6">
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
