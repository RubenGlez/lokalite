import Layout from "@/partials/Layout";
import Text from "@/components/Text";

export default function DashboardPage() {
  return (
    <Layout>
      <div className="p-8">
        <Text as="p" size="xs" color="secondary" className="mb-6">
          HOME
        </Text>
      </div>
    </Layout>
  );
}
