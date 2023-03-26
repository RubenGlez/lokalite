import Card from "@/components/Card";
import Layout from "@/components/Layout";
import { useFetch } from "@/hooks/useFetch";
import { useRouter } from "next/router";
import { Project } from "./api/project";

export default function Projects() {
  const router = useRouter();
  const { data } = useFetch<Project[]>("/api/project");
  const handleCardClick = (projectId: string) => () => {
    router.push(`/book?projectId=${projectId}`);
  };
  const handleCreateCardClick = () => {
    // TODO navigate
  };

  return (
    <Layout title="Projects">
      <div className="px-8 py-8">
        <div className="grid grid-cols-4 gap-6">
          {data?.map((project) => (
            <Card
              key={project.id}
              title={project.name}
              subtitle={project.description}
              description={"aqui los langs y la sheet"}
              onClick={handleCardClick(project.id)}
            />
          ))}
          <Card
            title="+ Create new proyect"
            subtitle="click here to create a new project"
            description=""
            onClick={handleCreateCardClick}
          />
        </div>
      </div>
    </Layout>
  );
}
