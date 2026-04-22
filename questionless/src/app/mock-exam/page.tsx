import Link from "next/link";
import {
  Clock,
  Target,
  AlertCircle,
  CheckCircle2,
  ArrowRight,
  BookOpen,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export const runtime = 'edge';

export default function MockExamPage() {
  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8 max-w-3xl">
        {/* Header */}
        <div className="text-center mb-8">
          <Badge variant="outline" className="mb-4">Mock Exam</Badge>
          <h1 className="text-3xl md:text-4xl font-bold font-nunito text-gray-900 mb-3">
            Life in the UK Practice Test
          </h1>
          <p className="text-muted-foreground text-lg">
            Simulate the real test conditions
          </p>
        </div>

        {/* Info Card */}
        <div className="card-clay-static p-6 md:p-8 mb-8">
          <div className="flex items-start gap-4 mb-6">
            <div className="bg-primary/10 p-3 rounded-xl">
              <Target className="h-8 w-8 text-primary" />
            </div>
            <div>
              <h2 className="text-xl font-bold font-nunito mb-2">Test Format</h2>
              <p className="text-muted-foreground">
                This mock exam follows the official Life in the UK test format exactly.
              </p>
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-4 mb-6">
            <div className="bg-muted/50 p-4 rounded-xl text-center">
              <BookOpen className="h-6 w-6 mx-auto mb-2 text-primary" />
              <div className="text-2xl font-bold font-nunito">24</div>
              <div className="text-sm text-muted-foreground">Questions</div>
            </div>
            <div className="bg-muted/50 p-4 rounded-xl text-center">
              <Clock className="h-6 w-6 mx-auto mb-2 text-amber-500" />
              <div className="text-2xl font-bold font-nunito">45</div>
              <div className="text-sm text-muted-foreground">Minutes</div>
            </div>
            <div className="bg-muted/50 p-4 rounded-xl text-center">
              <CheckCircle2 className="h-6 w-6 mx-auto mb-2 text-success-500" />
              <div className="text-2xl font-bold font-nunito">75%</div>
              <div className="text-sm text-muted-foreground">To Pass</div>
            </div>
          </div>

          <div className="space-y-3 mb-6">
            <h3 className="font-semibold">What to expect:</h3>
            <ul className="space-y-2 text-muted-foreground">
              <li className="flex items-start gap-2">
                <CheckCircle2 className="h-5 w-5 text-success-500 shrink-0 mt-0.5" />
                <span>24 multiple choice questions from all topic areas</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle2 className="h-5 w-5 text-success-500 shrink-0 mt-0.5" />
                <span>45-minute time limit (timer shown on screen)</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle2 className="h-5 w-5 text-success-500 shrink-0 mt-0.5" />
                <span>You need at least 18 correct answers (75%) to pass</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle2 className="h-5 w-5 text-success-500 shrink-0 mt-0.5" />
                <span>Results and explanations shown after completion</span>
              </li>
            </ul>
          </div>

          <div className="bg-amber-50 border border-amber-200 p-4 rounded-xl flex items-start gap-3">
            <AlertCircle className="h-5 w-5 text-amber-600 shrink-0 mt-0.5" />
            <div className="text-sm">
              <p className="font-medium text-amber-800">Important</p>
              <p className="text-amber-700">
                Once you start, the timer cannot be paused. Make sure you have 45 minutes of uninterrupted time.
              </p>
            </div>
          </div>
        </div>

        {/* CTA */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <Button asChild size="lg" className="btn-clay bg-gradient-primary text-white border-0 h-14 text-lg px-8">
            <Link href="/mock-exam/start">
              <Sparkles className="h-5 w-5 mr-2" />
              Start Mock Exam
            </Link>
          </Button>
          <Button asChild variant="outline" size="lg" className="h-14 shadow-clay-sm">
            <Link href="/practice">
              Practice More First
            </Link>
          </Button>
        </div>
      </div>
    </main>
  );
}
