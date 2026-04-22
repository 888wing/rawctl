import Link from "next/link";
import { XCircle, ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";

export const runtime = "edge";

export default function PricingCancelPage() {
  return (
    <main className="min-h-screen bg-muted/30 flex items-center justify-center p-4">
      <div className="card-clay-static p-8 md:p-12 max-w-lg w-full text-center">
        <div className="bg-muted w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6">
          <XCircle className="h-10 w-10 text-muted-foreground" />
        </div>

        <h1 className="text-2xl md:text-3xl font-bold font-nunito mb-3">
          Payment Cancelled
        </h1>
        <p className="text-muted-foreground mb-8">
          No worries! Your payment was not processed. You can continue using
          the free plan or try upgrading again when you&apos;re ready.
        </p>

        <div className="space-y-3">
          <Button
            asChild
            size="lg"
            className="w-full btn-clay bg-gradient-primary text-white border-0"
          >
            <Link href="/pricing">
              <ArrowLeft className="h-5 w-5 mr-2" />
              Back to Pricing
            </Link>
          </Button>
          <Button asChild variant="outline" size="lg" className="w-full shadow-clay-sm">
            <Link href="/practice">Continue Practicing Free</Link>
          </Button>
        </div>
      </div>
    </main>
  );
}
