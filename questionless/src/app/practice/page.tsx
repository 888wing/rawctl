import { Suspense } from "react";
import Link from "next/link";
import {
  ArrowRight,
  Shuffle,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { TOPICS } from "@/lib/topics";

export const runtime = 'edge';

// Topics from centralized config (replaces hardcoded array with fake question counts)
const topics = TOPICS;

export default function PracticePage() {
  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <Badge variant="outline" className="mb-4">Practice Mode</Badge>
          <h1 className="text-3xl md:text-4xl font-bold font-nunito text-gray-900 mb-3">
            Practice Questions
          </h1>
          <p className="text-muted-foreground text-lg">
            Choose a topic to start practicing or try random questions from all topics.
          </p>
        </div>

        {/* Quick Start */}
        <div className="card-clay-static bg-gradient-primary text-white mb-10 p-6 md:p-8">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              <div className="bg-white/20 p-4 rounded-2xl">
                <Shuffle className="h-8 w-8" />
              </div>
              <div>
                <h2 className="text-xl md:text-2xl font-bold font-nunito mb-1">Quick Practice</h2>
                <p className="text-white/80">
                  Answer 10 random questions from all topics
                </p>
              </div>
            </div>
            <Button asChild variant="secondary" size="lg" className="btn-clay shrink-0">
              <Link href="/practice/random">
                <Sparkles className="h-5 w-5 mr-2" />
                Start Random Practice
              </Link>
            </Button>
          </div>
        </div>

        {/* Topics Grid */}
        <div className="mb-6">
          <h2 className="text-xl font-bold font-nunito mb-2">Practice by Topic</h2>
          <p className="text-muted-foreground">Select a topic to focus your study session</p>
        </div>

        <Suspense fallback={<TopicsGridSkeleton />}>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
            {topics.map((topic) => {
              const Icon = topic.icon;
              return (
                <Link key={topic.slug} href={`/practice/${topic.slug}`} className="group">
                  <div className="card-clay h-full p-5">
                    <div className="flex items-start justify-between mb-4">
                      <div className={`p-3 rounded-xl ${topic.color} transition-transform group-hover:scale-110`}>
                        <Icon className="h-6 w-6" />
                      </div>
                    </div>
                    <h3 className="text-lg font-bold font-nunito mb-1">{topic.name}</h3>
                    <p className="text-muted-foreground text-sm mb-4">{topic.description}</p>
                    <span className="flex items-center text-sm font-medium text-primary group-hover:underline">
                      Start practicing
                      <ArrowRight className="h-4 w-4 ml-1 transition-transform group-hover:translate-x-1" />
                    </span>
                  </div>
                </Link>
              );
            })}
          </div>
        </Suspense>
      </div>
    </main>
  );
}

function TopicsGridSkeleton() {
  return (
    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
      {Array.from({ length: 9 }).map((_, i) => (
        <div key={i} className="card-clay-static h-full p-5">
          <div className="flex items-start justify-between mb-4">
            <Skeleton className="h-12 w-12 rounded-xl" />
            <Skeleton className="h-5 w-20 rounded-full" />
          </div>
          <Skeleton className="h-6 w-32 mb-2" />
          <Skeleton className="h-4 w-48 mb-4" />
          <Skeleton className="h-4 w-28" />
        </div>
      ))}
    </div>
  );
}
