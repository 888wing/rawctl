import { notFound } from "next/navigation";
import Link from "next/link";
import {
  ArrowRight,
  Clock,
  FileText,
  Percent,
  Sparkles,
  ArrowLeft,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { getExamBySlug, type ExamTopic } from "@/lib/exams";

export const runtime = "edge";

interface PageProps {
  params: Promise<{ exam: string }>;
}

export default async function ExamDetailPage({ params }: PageProps) {
  const { exam: examSlug } = await params;
  const exam = getExamBySlug(examSlug);

  if (!exam) {
    notFound();
  }

  const Icon = exam.icon;

  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8 max-w-5xl">
        {/* Back link */}
        <Link
          href="/exams"
          className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-6"
        >
          <ArrowLeft className="h-4 w-4 mr-1" />
          All Exams
        </Link>

        {/* Exam Header */}
        <div className="card-clay p-8 mb-8">
          <div className="flex flex-col md:flex-row items-start gap-6">
            <div
              className={`p-4 rounded-2xl ${exam.color} shrink-0`}
            >
              <Icon className="h-10 w-10" />
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-3 mb-2">
                <h1 className="text-2xl md:text-3xl font-bold font-nunito">
                  {exam.name}
                </h1>
                {exam.comingSoon && (
                  <Badge variant="outline">Coming Soon</Badge>
                )}
              </div>
              <p className="text-muted-foreground mb-4">{exam.description}</p>

              <div className="flex flex-wrap gap-3 mb-6">
                <Badge variant="secondary">
                  <FileText className="h-3.5 w-3.5 mr-1" />
                  {exam.examQuestions} questions
                </Badge>
                <Badge variant="secondary">
                  <Clock className="h-3.5 w-3.5 mr-1" />
                  {exam.examMinutes} minutes
                </Badge>
                <Badge variant="secondary">
                  <Percent className="h-3.5 w-3.5 mr-1" />
                  {exam.passPercent}% to pass
                </Badge>
                <Badge variant="secondary">{exam.fee} fee</Badge>
              </div>

              {exam.active ? (
                <Button
                  asChild
                  className="btn-clay bg-gradient-primary text-white border-0"
                >
                  <Link href="/practice">
                    <Sparkles className="h-4 w-4 mr-2" />
                    Start Practicing
                  </Link>
                </Button>
              ) : (
                <p className="text-sm text-muted-foreground italic">
                  Practice questions coming soon. Check back later!
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Topics Grid */}
        <div className="mb-6">
          <h2 className="text-xl font-bold font-nunito mb-2">
            {exam.topics.length} Topics
          </h2>
          <p className="text-muted-foreground text-sm">
            {exam.active
              ? "Select a topic to start practicing"
              : "Topics covered in this exam"}
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
          {exam.topics.map((topic) => (
            <TopicCard
              key={topic.slug}
              topic={topic}
              examSlug={examSlug}
              active={exam.active}
            />
          ))}
        </div>
      </div>
    </main>
  );
}

function TopicCard({
  topic,
  examSlug,
  active,
}: {
  topic: ExamTopic;
  examSlug: string;
  active: boolean;
}) {
  const Icon = topic.icon;

  const content = (
    <div
      className={`${active ? "card-clay" : "card-clay-static opacity-80"} h-full p-5`}
    >
      <div className="flex items-start justify-between mb-4">
        <div
          className={`p-3 rounded-xl ${topic.color} transition-transform ${active ? "group-hover:scale-110" : ""}`}
        >
          <Icon className="h-6 w-6" />
        </div>
      </div>
      <h3 className="text-lg font-bold font-nunito mb-1">{topic.name}</h3>
      <p className="text-muted-foreground text-sm mb-4">{topic.description}</p>
      {active && (
        <span className="flex items-center text-sm font-medium text-primary group-hover:underline">
          Start practicing
          <ArrowRight className="h-4 w-4 ml-1 transition-transform group-hover:translate-x-1" />
        </span>
      )}
    </div>
  );

  if (!active) return content;

  // For the default exam (life-in-uk), use existing /practice/[topic] route
  const href =
    examSlug === "life-in-uk"
      ? `/practice/${topic.slug}`
      : `/exams/${examSlug}/practice/${topic.slug}`;

  return (
    <Link href={href} className="group">
      {content}
    </Link>
  );
}
