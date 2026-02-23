import { notFound } from "next/navigation";
import { Suspense } from "react";
import Link from "next/link";
import { PracticeSession } from "@/components/question";
import { QuestionData } from "@/components/question/QuestionCard";
import { getTopicBySlug } from "@/lib/topics";

export const runtime = 'edge';

// Random topic meta (not in centralized config since it's a pseudo-topic)
const RANDOM_META = { name: "Random Practice", description: "Mixed questions from all topics", slug: "random" };

interface PageProps {
  params: Promise<{ topic: string }>;
}

// Skeleton loader
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

// Fetch questions from API
async function fetchQuestions(topic: string): Promise<QuestionData[]> {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

  try {
    if (topic === 'random') {
      const res = await fetch(`${baseUrl}/api/questions/random?count=20`, {
        cache: 'no-store',
      });
      if (!res.ok) return [];
      const data = await res.json() as { questions?: QuestionData[] };
      return data.questions || [];
    }

    const res = await fetch(`${baseUrl}/api/questions/topic/${topic}?limit=20`, {
      cache: 'no-store',
    });
    if (!res.ok) return [];
    const data = await res.json() as { questions?: QuestionData[] };
    return data.questions || [];
  } catch (error) {
    console.error('Error fetching questions:', error);
    return [];
  }
}

// Content component with questions
async function PracticeContent({ topic, meta }: { topic: string; meta: { name: string; description: string } }) {
  const questions = await fetchQuestions(topic);

  if (!questions || questions.length === 0) {
    return (
      <div className="min-h-screen bg-gradient-hero p-4 sm:p-6">
        <div className="max-w-2xl mx-auto">
          <div className="card-clay p-8 text-center">
            <h2 className="text-2xl font-nunito font-bold text-slate-800 mb-4">
              No Questions Available
            </h2>
            <p className="text-slate-600 mb-6">
              Questions for {meta.name} are coming soon! Check back later.
            </p>
            <Link href="/practice" className="btn-clay inline-block px-6 py-3">
              Back to Topics
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const formattedQuestions = questions;

  return (
    <main className="min-h-screen bg-gradient-hero">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-nunito font-bold text-slate-800 mb-2">
            {meta.name}
          </h1>
          <p className="text-slate-600">
            {meta.description}
          </p>
        </div>

        {/* Practice Session */}
        <PracticeSession questions={formattedQuestions} topic={meta.name} />
      </div>
    </main>
  );
}

export default async function TopicPracticePage({ params }: PageProps) {
  const { topic } = await params;

  // Validate topic exists — check centralized config or random pseudo-topic
  const topicConfig = topic === "random" ? RANDOM_META : getTopicBySlug(topic);
  if (!topicConfig) {
    notFound();
  }
  const meta = { name: topicConfig.name, description: topicConfig.description };

  return (
    <Suspense fallback={<QuestionsSkeleton />}>
      <PracticeContent topic={topic} meta={meta} />
    </Suspense>
  );
}

