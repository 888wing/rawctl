import Link from "next/link";
import { CheckCircle2, ArrowRight, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";

export const runtime = "edge";

export default function PricingSuccessPage() {
  return (
    <main className="min-h-screen bg-muted/30 flex items-center justify-center p-4">
      <div className="card-clay-static p-8 md:p-12 max-w-lg w-full text-center">
        <div className="bg-green-100 w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6">
          <CheckCircle2 className="h-10 w-10 text-green-600" />
        </div>

        <h1 className="text-2xl md:text-3xl font-bold font-nunito mb-3">
          Welcome to Pro!
        </h1>
        <p className="text-muted-foreground mb-8">
          Your payment was successful. You now have access to all Pro features
          including mock exams, spaced repetition, and detailed analytics.
        </p>

        <div className="space-y-3">
          <Button
            asChild
            size="lg"
            className="w-full btn-clay bg-gradient-primary text-white border-0"
          >
            <Link href="/dashboard">
              <Sparkles className="h-5 w-5 mr-2" />
              Go to Dashboard
            </Link>
          </Button>
          <Button asChild variant="outline" size="lg" className="w-full shadow-clay-sm">
            <Link href="/mock-exam">
              Take a Mock Exam
              <ArrowRight className="h-4 w-4 ml-2" />
            </Link>
          </Button>
        </div>
      </div>
    </main>
  );
}
