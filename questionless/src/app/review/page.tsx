import Link from "next/link";
import { Suspense } from "react";
import { auth } from "@clerk/nextjs/server";
import { getRequestContext } from "@cloudflare/next-on-pages";
import { getDb } from "@/lib/db";
import { srRecords, userAnswers } from "@/lib/db/schema";
import { eq, sql, and, gte } from "drizzle-orm";
import {
  RotateCcw,
  Brain,
  Target,
  TrendingUp,
  Clock,
  CheckCircle2,
  XCircle,
  ArrowRight,
  Sparkles,
  AlertCircle,
  BookOpen,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

export const runtime = "edge";

export default async function ReviewPage() {
  const { userId } = await auth();

  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8 max-w-4xl">
        {/* Header */}
        <div className="text-center mb-8">
          <Badge variant="outline" className="mb-4">Smart Review</Badge>
          <h1 className="text-3xl md:text-4xl font-bold font-nunito text-gray-900 mb-3">
            Spaced Repetition Review
          </h1>
          <p className="text-muted-foreground text-lg">
            Focus on questions you need to practice most
          </p>
        </div>

        {/* How it works */}
        <div className="card-clay-static p-6 md:p-8 mb-8">
          <div className="flex items-start gap-4 mb-6">
            <div className="bg-amber-100 p-3 rounded-xl">
              <Brain className="h-8 w-8 text-amber-600" />
            </div>
            <div>
              <h2 className="text-xl font-bold font-nunito mb-2">How Smart Review Works</h2>
              <p className="text-muted-foreground">
                Our spaced repetition algorithm tracks your performance and schedules reviews at optimal intervals.
              </p>
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-4 mb-6">
            <div className="bg-muted/50 p-4 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <XCircle className="h-5 w-5 text-destructive" />
                <span className="font-semibold">Wrong Answers</span>
              </div>
              <p className="text-sm text-muted-foreground">
                Questions you got wrong are reviewed more frequently until mastered.
              </p>
            </div>
            <div className="bg-muted/50 p-4 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <Clock className="h-5 w-5 text-amber-500" />
                <span className="font-semibold">Optimal Timing</span>
              </div>
              <p className="text-sm text-muted-foreground">
                Questions appear just before you&apos;re likely to forget them.
              </p>
            </div>
            <div className="bg-muted/50 p-4 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <TrendingUp className="h-5 w-5 text-success-500" />
                <span className="font-semibold">Progress Tracking</span>
              </div>
              <p className="text-sm text-muted-foreground">
                Watch your mastery level increase as you review consistently.
              </p>
            </div>
          </div>
        </div>

        {/* Review Stats */}
        <Suspense fallback={<ReviewStatsSkeleton />}>
          <ReviewStats userId={userId} />
        </Suspense>

        {/* Review Queue */}
        <Suspense fallback={<ReviewQueueSkeleton />}>
          <ReviewQueue userId={userId} />
        </Suspense>
      </div>
    </main>
  );
}

// Review Stats Component
async function ReviewStats({ userId }: { userId: string | null }) {
  if (!userId) {
    return <ReviewStatsDisplay stats={{ dueToday: 0, mastered: 0, learning: 0, streak: 0 }} />;
  }

  const { env } = getRequestContext();
  const db = getDb(env.DB);
  const now = new Date().toISOString();

  // Due today: SR records where nextReviewAt <= now
  const dueResult = await db
    .select({ count: sql<number>`COUNT(*)` })
    .from(srRecords)
    .where(and(eq(srRecords.userId, userId), sql`${srRecords.nextReviewAt} <= ${now}`));

  // Mastered: SR records with repetitions >= 5 (well-learned)
  const masteredResult = await db
    .select({ count: sql<number>`COUNT(*)` })
    .from(srRecords)
    .where(and(eq(srRecords.userId, userId), gte(srRecords.repetitions, 5)));

  // Learning: SR records with repetitions > 0 and < 5
  const learningResult = await db
    .select({ count: sql<number>`COUNT(*)` })
    .from(srRecords)
    .where(
      and(
        eq(srRecords.userId, userId),
        sql`${srRecords.repetitions} > 0 AND ${srRecords.repetitions} < 5`
      )
    );

  // Streak calculation from user_answers
  const today = new Date();
  const thirtyDaysAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
  const recentActivity = await db
    .select({ date: sql<string>`DATE(${userAnswers.createdAt})` })
    .from(userAnswers)
    .where(
      and(
        eq(userAnswers.userId, userId),
        gte(userAnswers.createdAt, thirtyDaysAgo.toISOString())
      )
    )
    .groupBy(sql`DATE(${userAnswers.createdAt})`)
    .orderBy(sql`DATE(${userAnswers.createdAt}) DESC`);

  let streak = 0;
  const dates = recentActivity.map((r) => r.date);
  for (let i = 0; i < 30; i++) {
    const checkDate = new Date(today.getTime() - i * 24 * 60 * 60 * 1000);
    const checkDateStr = checkDate.toISOString().split("T")[0];
    if (dates.includes(checkDateStr)) {
      streak++;
    } else if (i > 0) {
      break;
    }
  }

  const stats = {
    dueToday: dueResult[0]?.count ?? 0,
    mastered: masteredResult[0]?.count ?? 0,
    learning: learningResult[0]?.count ?? 0,
    streak,
  };

  return <ReviewStatsDisplay stats={stats} />;
}

interface ReviewStatsData {
  dueToday: number;
  mastered: number;
  learning: number;
  streak: number;
}

function ReviewStatsDisplay({ stats }: { stats: ReviewStatsData }) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <div className="card-clay-static p-4 text-center">
        <div className="bg-primary/10 w-12 h-12 rounded-xl flex items-center justify-center mx-auto mb-3">
          <Target className="h-6 w-6 text-primary" />
        </div>
        <div className="text-2xl font-bold font-nunito">{stats.dueToday}</div>
        <div className="text-sm text-muted-foreground">Due Today</div>
      </div>
      <div className="card-clay-static p-4 text-center">
        <div className="bg-success-100 w-12 h-12 rounded-xl flex items-center justify-center mx-auto mb-3">
          <CheckCircle2 className="h-6 w-6 text-success-600" />
        </div>
        <div className="text-2xl font-bold font-nunito">{stats.mastered}</div>
        <div className="text-sm text-muted-foreground">Mastered</div>
      </div>
      <div className="card-clay-static p-4 text-center">
        <div className="bg-amber-100 w-12 h-12 rounded-xl flex items-center justify-center mx-auto mb-3">
          <BookOpen className="h-6 w-6 text-amber-600" />
        </div>
        <div className="text-2xl font-bold font-nunito">{stats.learning}</div>
        <div className="text-sm text-muted-foreground">Learning</div>
      </div>
      <div className="card-clay-static p-4 text-center">
        <div className="bg-purple-100 w-12 h-12 rounded-xl flex items-center justify-center mx-auto mb-3">
          <RotateCcw className="h-6 w-6 text-purple-600" />
        </div>
        <div className="text-2xl font-bold font-nunito">{stats.streak} days</div>
        <div className="text-sm text-muted-foreground">Review Streak</div>
      </div>
    </div>
  );
}

// Review Queue Component
async function ReviewQueue({ userId }: { userId: string | null }) {
  let dueReviews = 0;

  if (userId) {
    const { env } = getRequestContext();
    const db = getDb(env.DB);
    const now = new Date().toISOString();

    const dueResult = await db
      .select({ count: sql<number>`COUNT(*)` })
      .from(srRecords)
      .where(and(eq(srRecords.userId, userId), sql`${srRecords.nextReviewAt} <= ${now}`));

    dueReviews = dueResult[0]?.count ?? 0;
  }

  if (dueReviews === 0) {
    return (
      <div className="card-clay-static p-8 text-center">
        <div className="bg-success-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
          <CheckCircle2 className="h-8 w-8 text-success-600" />
        </div>
        <h2 className="text-xl font-bold font-nunito mb-2">All Caught Up!</h2>
        <p className="text-muted-foreground mb-6 max-w-md mx-auto">
          You don&apos;t have any questions due for review right now. Keep practicing to build your review queue!
        </p>
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <Button asChild size="lg" className="btn-clay bg-gradient-primary text-white border-0">
            <Link href="/practice">
              <Sparkles className="h-5 w-5 mr-2" />
              Practice More
            </Link>
          </Button>
          <Button asChild variant="outline" size="lg" className="shadow-clay-sm">
            <Link href="/mock-exam">
              <Target className="h-5 w-5 mr-2" />
              Take Mock Exam
            </Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="card-clay-static p-6 md:p-8">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-bold font-nunito">Ready for Review</h2>
          <p className="text-muted-foreground">
            {dueReviews} questions waiting for you
          </p>
        </div>
        <Badge className="bg-amber-100 text-amber-800 border-amber-200">
          {dueReviews} Due
        </Badge>
      </div>

      <div className="bg-amber-50 border border-amber-200 p-4 rounded-xl flex items-start gap-3 mb-6">
        <AlertCircle className="h-5 w-5 text-amber-600 shrink-0 mt-0.5" />
        <div className="text-sm">
          <p className="font-medium text-amber-800">Review Tip</p>
          <p className="text-amber-700">
            Consistent daily reviews are more effective than cramming. Try to review a little each day!
          </p>
        </div>
      </div>

      <Button asChild size="lg" className="w-full btn-clay bg-gradient-primary text-white border-0 h-14 text-lg">
        <Link href="/review/session">
          Start Review Session
          <ArrowRight className="h-5 w-5 ml-2" />
        </Link>
      </Button>
    </div>
  );
}

// Skeleton Components
function ReviewStatsSkeleton() {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="card-clay-static p-4 text-center">
          <Skeleton className="w-12 h-12 rounded-xl mx-auto mb-3" />
          <Skeleton className="h-8 w-12 mx-auto mb-1" />
          <Skeleton className="h-4 w-20 mx-auto" />
        </div>
      ))}
    </div>
  );
}

function ReviewQueueSkeleton() {
  return (
    <div className="card-clay-static p-8">
      <Skeleton className="h-16 w-16 rounded-full mx-auto mb-4" />
      <Skeleton className="h-6 w-32 mx-auto mb-2" />
      <Skeleton className="h-4 w-64 mx-auto mb-6" />
      <Skeleton className="h-12 w-48 mx-auto" />
    </div>
  );
}
