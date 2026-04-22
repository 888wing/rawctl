import { notFound } from "next/navigation";
import { Suspense } from "react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { PracticeSession } from "@/components/question";
import { QuestionData } from "@/components/question/QuestionCard";
import { getExamBySlug, getExamTopicBySlug } from "@/lib/exams";

export const runtime = "edge";

interface PageProps {
  params: Promise<{ exam: string; topic: string }>;
}

function QuestionsSkeleton() {
  return (
    <div className="min-h-screen bg-gradient-hero p-4 sm:p-6">
      <div className="max-w-2xl mx-auto">
        <div className="card-clay p-6 sm:p-8 animate-pulse">
          <div className="h-8 bg-slate-200 rounded w-3/4 mb-6" />
          <div className="space-y-3">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-14 bg-slate-200 rounded-xl" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

async function fetchQuestions(
  exam: string,
  topic: string
): Promise<QuestionData[]> {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000";

  try {
    // Use the topic-based API with exam filter
    const res = await fetch(
      `${baseUrl}/api/questions/topic/${topic}?limit=20&exam=${exam}`,
      { cache: "no-store" }
    );
    if (!res.ok) return [];
    const data = (await res.json()) as { questions?: QuestionData[] };
    return data.questions || [];
  } catch (error) {
    console.error("Error fetching questions:", error);
    return [];
  }
}

async function PracticeContent({
  examSlug,
  topicSlug,
  examName,
  topicName,
  topicDescription,
}: {
  examSlug: string;
  topicSlug: string;
  examName: string;
  topicName: string;
  topicDescription: string;
}) {
  const questions = await fetchQuestions(examSlug, topicSlug);

  if (!questions || questions.length === 0) {
    return (
      <div className="min-h-screen bg-gradient-hero p-4 sm:p-6">
        <div className="max-w-2xl mx-auto">
          <div className="card-clay p-8 text-center">
            <h2 className="text-2xl font-nunito font-bold text-slate-800 mb-4">
              No Questions Available
            </h2>
            <p className="text-slate-600 mb-6">
              Questions for {topicName} ({examName}) are coming soon! Check back
              later.
            </p>
            <Link
              href={`/exams/${examSlug}`}
              className="btn-clay inline-block px-6 py-3"
            >
              Back to {examName}
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-gradient-hero">
      <div className="container mx-auto px-4 py-8">
        <Link
          href={`/exams/${examSlug}`}
          className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-6"
        >
          <ArrowLeft className="h-4 w-4 mr-1" />
          Back to {examName}
        </Link>

        <div className="mb-8 text-center">
          <h1 className="text-2xl font-nunito font-bold text-slate-800 mb-2">
            {topicName}
          </h1>
          <p className="text-slate-600">{topicDescription}</p>
        </div>

        <PracticeSession questions={questions} topic={topicName} />
      </div>
    </main>
  );
}

export default async function ExamTopicPracticePage({ params }: PageProps) {
  const { exam: examSlug, topic: topicSlug } = await params;

  const exam = getExamBySlug(examSlug);
  if (!exam) notFound();

  const topic = getExamTopicBySlug(examSlug, topicSlug);
  if (!topic) notFound();

  return (
    <Suspense fallback={<QuestionsSkeleton />}>
      <PracticeContent
        examSlug={examSlug}
        topicSlug={topicSlug}
        examName={exam.name}
        topicName={topic.name}
        topicDescription={topic.description}
      />
    </Suspense>
  );
}
