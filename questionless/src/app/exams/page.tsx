import Link from "next/link";
import {
  ArrowRight,
  Clock,
  FileText,
  Percent,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { getAllExams, type ExamConfig } from "@/lib/exams";

export const runtime = "edge";

export default function ExamsPage() {
  const exams = getAllExams();
  const activeExams = exams.filter((e) => e.active);
  const comingSoonExams = exams.filter((e) => e.comingSoon);

  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8 max-w-5xl">
        {/* Header */}
        <div className="text-center mb-10">
          <Badge variant="outline" className="mb-4">All Exams</Badge>
          <h1 className="text-3xl md:text-4xl font-bold font-nunito text-gray-900 mb-3">
            Choose Your Exam
          </h1>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
            AI-powered practice for UK public exams. Choose an exam to start preparing.
          </p>
        </div>

        {/* Active Exams */}
        {activeExams.length > 0 && (
          <div className="mb-12">
            <h2 className="text-xl font-bold font-nunito mb-6 flex items-center gap-2">
              <Sparkles className="h-5 w-5 text-primary" />
              Available Now
            </h2>
            <div className="grid md:grid-cols-2 gap-6">
              {activeExams.map((exam) => (
                <ExamCard key={exam.slug} exam={exam} />
              ))}
            </div>
          </div>
        )}

        {/* Coming Soon Exams */}
        {comingSoonExams.length > 0 && (
          <div>
            <h2 className="text-xl font-bold font-nunito mb-6 flex items-center gap-2">
              <Clock className="h-5 w-5 text-muted-foreground" />
              Coming Soon
            </h2>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {comingSoonExams.map((exam) => (
                <ComingSoonCard key={exam.slug} exam={exam} />
              ))}
            </div>
          </div>
        )}
      </div>
    </main>
  );
}

function ExamCard({ exam }: { exam: ExamConfig }) {
  const Icon = exam.icon;
  return (
    <Link href="/practice" className="block group">
      <div className="card-clay p-6 h-full">
        <div className="flex items-start gap-4 mb-4">
          <div className={`p-3 rounded-xl ${exam.color} transition-transform group-hover:scale-110`}>
            <Icon className="h-7 w-7" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold font-nunito mb-1">{exam.name}</h3>
            <p className="text-sm text-muted-foreground">{exam.tagline}</p>
          </div>
        </div>

        <p className="text-muted-foreground text-sm mb-4">{exam.description}</p>

        {/* Exam details */}
        <div className="flex flex-wrap gap-2 mb-5">
          <Badge variant="secondary" className="text-xs">
            <FileText className="h-3 w-3 mr-1" />
            {exam.examQuestions} questions
          </Badge>
          <Badge variant="secondary" className="text-xs">
            <Clock className="h-3 w-3 mr-1" />
            {exam.examMinutes} min
          </Badge>
          <Badge variant="secondary" className="text-xs">
            <Percent className="h-3 w-3 mr-1" />
            {exam.passPercent}% to pass
          </Badge>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-xs text-muted-foreground">
            {exam.topics.length} topics &middot; Fee: {exam.fee}
          </span>
          <span className="flex items-center text-sm font-medium text-primary group-hover:underline">
            Start practicing
            <ArrowRight className="h-4 w-4 ml-1 transition-transform group-hover:translate-x-1" />
          </span>
        </div>
      </div>
    </Link>
  );
}

function ComingSoonCard({ exam }: { exam: ExamConfig }) {
  const Icon = exam.icon;
  return (
    <div className="card-clay-static p-6 h-full opacity-80">
      <div className="flex items-start gap-4 mb-4">
        <div className={`p-3 rounded-xl ${exam.color}`}>
          <Icon className="h-6 w-6" />
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <h3 className="text-lg font-bold font-nunito">{exam.name}</h3>
            <Badge variant="outline" className="text-xs">Coming Soon</Badge>
          </div>
          <p className="text-sm text-muted-foreground">{exam.tagline}</p>
        </div>
      </div>

      <p className="text-muted-foreground text-sm mb-4">{exam.description}</p>

      <div className="flex flex-wrap gap-2">
        <Badge variant="secondary" className="text-xs">
          <FileText className="h-3 w-3 mr-1" />
          {exam.examQuestions} questions
        </Badge>
        <Badge variant="secondary" className="text-xs">
          <Clock className="h-3 w-3 mr-1" />
          {exam.examMinutes} min
        </Badge>
        <Badge variant="secondary" className="text-xs">
          {exam.topics.length} topics
        </Badge>
      </div>
    </div>
  );
}
