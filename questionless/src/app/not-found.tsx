import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Home } from "lucide-react";

export const runtime = "edge";

export default function NotFound() {
  return (
    <main className="min-h-screen bg-muted/30 flex items-center justify-center p-4">
      <div className="card-clay-static p-8 md:p-12 max-w-lg w-full text-center">
        <div className="text-6xl font-bold font-nunito text-muted-foreground/30 mb-4">
          404
        </div>
        <h1 className="text-2xl font-bold font-nunito mb-3">Page Not Found</h1>
        <p className="text-muted-foreground mb-8">
          The page you&apos;re looking for doesn&apos;t exist or has been moved.
        </p>
        <Button
          asChild
          size="lg"
          className="btn-clay bg-gradient-primary text-white border-0"
        >
          <Link href="/">
            <Home className="h-5 w-5 mr-2" />
            Back to Home
          </Link>
        </Button>
      </div>
    </main>
  );
}
