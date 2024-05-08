import { Button } from "@/components/ui/button";
import { TypographyH1, TypographyP } from "@/components/ui/typography";
import Link from "next/link";

export default function Home() {
  return (
    <main className="flex flex-col p-24">
      <TypographyH1>Home page</TypographyH1>

      <TypographyP>
        This page is public, an is the main entry point for all users
      </TypographyP>

      <div className="flex gap-4 mt-8">
        <Button asChild>
          <Link href="/signin">SignIn</Link>
        </Button>
        <Button variant="outline">
          <Link href="/signup">SignUp</Link>
        </Button>
      </div>
    </main>
  );
}
