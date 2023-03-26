import Card from "@/components/Card";
import Layout from "@/components/Layout";
import { useFetch } from "@/hooks/useFetch";
import { useRouter } from "next/router";
import { Book } from "../api/book";

export default function Books() {
  const router = useRouter();
  const { data } = useFetch<Book[]>("/api/book");
  const handleCardClick = (bookId: string) => () => {
    router.push(`/books/${bookId}`);
  };
  const handleCreateCardClick = () => {
    // TODO navigate
  };

  return (
    <Layout title="Books">
      <div className="px-8 py-8">
        <div className="grid grid-cols-4 gap-6">
          {data?.map((book) => (
            <Card
              key={book.id}
              title={book.name}
              subtitle={book.description}
              description={`[${book.defaultLang}] ${book.langs.join(", ")}`}
              onClick={handleCardClick(book.id)}
            />
          ))}
          <Card
            title="+ Crear libro"
            subtitle="Haz click para crear un nuevo libro"
            description=""
            onClick={handleCreateCardClick}
          />
        </div>
      </div>
    </Layout>
  );
}
