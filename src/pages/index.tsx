import Layout from "@/components/Layout";

const projects = [
  {
    name: "Desk and Office",
    description: "Work from home accessories",
    imageSrc:
      "https://tailwindui.com/img/ecommerce-images/home-page-02-edition-01.jpg",
    imageAlt:
      "Desk with leather desk pad, walnut desk organizer, wireless keyboard and mouse, and porcelain mug.",
    href: "#",
  },
  {
    name: "Self-Improvement",
    description: "Journals and note-taking",
    imageSrc:
      "https://tailwindui.com/img/ecommerce-images/home-page-02-edition-02.jpg",
    imageAlt:
      "Wood table with porcelain mug, leather journal, brass pen, leather key ring, and a houseplant.",
    href: "#",
  },
  {
    name: "Travel",
    description: "Daily commute essentials",
    imageSrc:
      "https://tailwindui.com/img/ecommerce-images/home-page-02-edition-03.jpg",
    imageAlt: "Collection of four insulated travel bottles on wooden shelf.",
    href: "#",
  },
  {
    name: "Desk and Office",
    description: "Work from home accessories",
    imageSrc:
      "https://tailwindui.com/img/ecommerce-images/home-page-02-edition-01.jpg",
    imageAlt:
      "Desk with leather desk pad, walnut desk organizer, wireless keyboard and mouse, and porcelain mug.",
    href: "#",
  },
  {
    name: "Self-Improvement",
    description: "Journals and note-taking",
    imageSrc:
      "https://tailwindui.com/img/ecommerce-images/home-page-02-edition-02.jpg",
    imageAlt:
      "Wood table with porcelain mug, leather journal, brass pen, leather key ring, and a houseplant.",
    href: "#",
  },
  {
    name: "Travel",
    description: "Daily commute essentials",
    imageSrc:
      "https://tailwindui.com/img/ecommerce-images/home-page-02-edition-03.jpg",
    imageAlt: "Collection of four insulated travel bottles on wooden shelf.",
    href: "#",
  },
];

export default function Dashboard() {
  return (
    <Layout title="Dashboard">
      <div className="grid grid-cols-4 gap-6 px-4 py-8">
        {projects.map((project, index) => (
          <div
            key={project.name}
            className="border border-1 border-slate-600 rounded"
          >
            <div className="px-6 py-4">
              <div className="text-slate-400 text-base mb-2">
                {project.name}
              </div>
              <p className="text-slate-500 text-base">{project.description}</p>
            </div>
          </div>
        ))}
        <div
          key={"createNew"}
          className="border border-1 border-slate-600 rounded"
        >
          <div className="px-6 py-4">
            <div className="text-slate-400 text-base mb-2">
              + Create new proyect
            </div>
            <p className="text-slate-500 text-base">
              click here to create a new project
            </p>
          </div>
        </div>
      </div>
    </Layout>
  );
}
