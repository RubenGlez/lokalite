import { Button } from "@/components/ui/button";

export default function Home() {
  return (
    <main className="flex flex-col p-24 gap-4">
      <h1 className="text-xl">Home page</h1>
      <p className="text-sm text-slate-500">
        This page is public, an is the main entry point for all users
      </p>

      <div className="flex gap-4">
        <Button>SignIn</Button>
        <Button variant="outline">SignUp</Button>
      </div>
    </main>
  );
}
