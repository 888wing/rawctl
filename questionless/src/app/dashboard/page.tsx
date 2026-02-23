import { Suspense } from "react";
import { auth, currentUser } from "@clerk/nextjs/server";
import Link from "next/link";
import {
  BookOpen,
  Target,
  RotateCcw,
  TrendingUp,
  Percent,
  FileCheck,
  Flame,
  ArrowRight,
  Clock,
  Sparkles,
  Trophy,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { getRequestContext } from "@cloudflare/next-on-pages";
import { getDb } from "@/lib/db";
import { userAnswers, questions, mockExams, srRecords } from "@/lib/db/schema";
import { eq, sql, and, gte } from "drizzle-orm";

export const runtime = "edge";

export default async function DashboardPage() {
  // Parallelize auth requests (async-parallel rule)
  const [{ userId }, user] = await Promise.all([
    auth(),
    currentUser()
  ]);

  const firstName = user?.firstName || "Learner";
  const greeting = getGreeting();

  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8">
        {/* Welcome Section */}
        <div className="card-clay-static p-6 md:p-8 mb-8">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <p className="text-muted-foreground mb-1">{greeting}</p>
              <h1 className="text-2xl md:text-3xl font-bold font-nunito text-gray-900">
                Welcome back, {firstName}!
              </h1>
              <p className="text-muted-foreground mt-2">
                Continue your Life in the UK test preparation
              </p>
            </div>
            <Button asChild size="lg" className="btn-clay bg-gradient-primary text-white border-0">
              <Link href="/practice">
                <Sparkles className="h-4 w-4 mr-2" />
                Continue Learning
              </Link>
            </Button>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          <Link href="/practice" className="block group">
            <div className="card-clay bg-gradient-primary text-white h-full p-6">
              <BookOpen className="h-8 w-8 mb-4" />
              <h3 className="text-lg font-bold font-nunito mb-2">Practice Questions</h3>
              <p className="text-white/80 text-sm mb-4">
                Practice by topic or random questions
              </p>
              <span className="flex items-center text-sm font-medium group-hover:underline">
                Start practicing <ArrowRight className="h-4 w-4 ml-1" />
              </span>
            </div>
          </Link>

          <Link href="/mock-exam/start" className="block group">
            <div className="card-clay h-full p-6 border-2 border-primary/20 hover:border-primary/40 transition-colors">
              <Target className="h-8 w-8 mb-4 text-primary" />
              <h3 className="text-lg font-bold font-nunito mb-2">Mock Exam</h3>
              <p className="text-muted-foreground text-sm mb-4">
                24 questions in 45 minutes
              </p>
              <span className="flex items-center text-sm font-medium text-primary group-hover:underline">
                Take exam <ArrowRight className="h-4 w-4 ml-1" />
              </span>
            </div>
          </Link>

          <Link href="/review" className="block group">
            <div className="card-clay h-full p-6">
              <RotateCcw className="h-8 w-8 mb-4 text-amber-500" />
              <h3 className="text-lg font-bold font-nunito mb-2">Smart Review</h3>
              <p className="text-muted-foreground text-sm mb-4">
                Review questions you got wrong
              </p>
              <span className="flex items-center text-sm font-medium text-amber-600 group-hover:underline">
                Start review <ArrowRight className="h-4 w-4 ml-1" />
              </span>
            </div>
          </Link>
        </div>

        {/* Progress Overview */}
        <div className="grid md:grid-cols-2 gap-6">
          {/* Stats Card */}
          <Suspense fallback={<StatsCardSkeleton />}>
            <StatsCard userId={userId} />
          </Suspense>

          {/* Topics Progress */}
          <Suspense fallback={<TopicsProgressSkeleton />}>
            <TopicsProgressCard userId={userId} />
          </Suspense>
        </div>

        {/* Today's Review */}
        <Suspense fallback={<ReviewBannerSkeleton />}>
          <ReviewBanner userId={userId} />
        </Suspense>
      </div>
    </main>
  );
}

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

// Stats Card Component
async function StatsCard({ userId }: { userId: string | null }) {
  if (!userId) return <StatsCardEmpty />;

  const { env } = getRequestContext();
  const db = getDb(env.DB);

  const totalStats = await db
    .select({
      totalAnswered: sql<number>`COUNT(*)`,
      correctAnswers: sql<number>`SUM(CASE WHEN ${userAnswers.isCorrect} THEN 1 ELSE 0 END)`,
    })
    .from(userAnswers)
    .where(eq(userAnswers.userId, userId));

  const examStats = await db
    .select({
      totalExams: sql<number>`COUNT(*)`,
    })
    .from(mockExams)
    .where(eq(mockExams.userId, userId));

  // Calculate streak from recent activity
  const today = new Date();
  const thirtyDaysAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
  const recentActivity = await db
    .select({ date: sql<string>`DATE(${userAnswers.createdAt})` })
    .from(userAnswers)
    .where(and(eq(userAnswers.userId, userId), gte(userAnswers.createdAt, thirtyDaysAgo.toISOString())))
    .groupBy(sql`DATE(${userAnswers.createdAt})`)
    .orderBy(sql`DATE(${userAnswers.createdAt}) DESC`);

  let streak = 0;
  const dates = recentActivity.map(r => r.date);
  for (let i = 0; i < 30; i++) {
    const checkDate = new Date(today.getTime() - i * 24 * 60 * 60 * 1000);
    const checkDateStr = checkDate.toISOString().split("T")[0];
    if (dates.includes(checkDateStr)) {
      streak++;
    } else if (i > 0) {
      break;
    }
  }

  const { totalAnswered, correctAnswers } = totalStats[0] || { totalAnswered: 0, correctAnswers: 0 };
  const accuracy = totalAnswered > 0 ? Math.round((correctAnswers / totalAnswered) * 100) : 0;
  const mockExamsTaken = examStats[0]?.totalExams ?? 0;

  return (
    <div className="card-clay-static p-6">
      <h2 className="text-lg font-bold font-nunito mb-6 flex items-center gap-2">
        <TrendingUp className="h-5 w-5 text-primary" />
        Your Progress
      </h2>
      <div className="grid grid-cols-2 gap-4">
        <StatItem
          icon={TrendingUp}
          label="Questions Answered"
          value={totalAnswered.toString()}
          color="bg-primary/10 text-primary"
        />
        <StatItem
          icon={Percent}
          label="Accuracy"
          value={`${accuracy}%`}
          color="bg-green-100 text-green-600"
        />
        <StatItem
          icon={FileCheck}
          label="Mock Exams Taken"
          value={mockExamsTaken.toString()}
          color="bg-purple-100 text-purple-600"
        />
        <StatItem
          icon={Flame}
          label="Study Streak"
          value={`${streak} days`}
          color="bg-amber-100 text-amber-600"
          highlight={streak > 0}
        />
      </div>
    </div>
  );
}

function StatsCardEmpty() {
  return (
    <div className="card-clay-static p-6">
      <h2 className="text-lg font-bold font-nunito mb-6 flex items-center gap-2">
        <TrendingUp className="h-5 w-5 text-primary" />
        Your Progress
      </h2>
      <div className="grid grid-cols-2 gap-4">
        <StatItem
          icon={TrendingUp}
          label="Questions Answered"
          value="0"
          color="bg-primary/10 text-primary"
        />
        <StatItem
          icon={Percent}
          label="Accuracy"
          value="0%"
          color="bg-green-100 text-green-600"
        />
        <StatItem
          icon={FileCheck}
          label="Mock Exams Taken"
          value="0"
          color="bg-purple-100 text-purple-600"
        />
        <StatItem
          icon={Flame}
          label="Study Streak"
          value="0 days"
          color="bg-amber-100 text-amber-600"
        />
      </div>
    </div>
  );
}

function StatItem({
  icon: Icon,
  label,
  value,
  color,
  highlight = false,
}: {
  icon: React.ElementType;
  label: string;
  value: string;
  color: string;
  highlight?: boolean;
}) {
  return (
    <div className={`rounded-xl p-4 ${highlight ? 'ring-2 ring-amber-400 animate-pulse-glow' : 'bg-muted/50'}`}>
      <div className="flex items-center gap-2 mb-2">
        <div className={`p-1.5 rounded-lg ${color}`}>
          <Icon className="h-4 w-4" />
        </div>
        <span className="text-sm text-muted-foreground">{label}</span>
      </div>
      <p className="text-2xl font-bold font-nunito">{value}</p>
    </div>
  );
}

// Topic color mapping from centralized config
import { DB_TO_COLOR } from "@/lib/topics";
const topicColors = DB_TO_COLOR;

// Topics Progress Card
async function TopicsProgressCard({ userId }: { userId: string | null }) {
  if (!userId) return <TopicsProgressEmpty />;

  const { env } = getRequestContext();
  const db = getDb(env.DB);

  const topicStats = await db
    .select({
      topic: questions.topic,
      total: sql<number>`COUNT(*)`,
      correct: sql<number>`SUM(CASE WHEN ${userAnswers.isCorrect} THEN 1 ELSE 0 END)`,
    })
    .from(userAnswers)
    .innerJoin(questions, eq(userAnswers.questionId, questions.id))
    .where(eq(userAnswers.userId, userId))
    .groupBy(questions.topic);

  const topicProgress = topicStats.length > 0
    ? topicStats.slice(0, 4).map(t => ({
        topic: t.topic,
        progress: t.total > 0 ? Math.round((t.correct / t.total) * 100) : 0,
        color: topicColors[t.topic] || "bg-gray-500",
      }))
    : [
        { topic: "British History", progress: 0, color: "bg-amber-500" },
        { topic: "UK Government", progress: 0, color: "bg-blue-500" },
        { topic: "Laws and Rights", progress: 0, color: "bg-purple-500" },
        { topic: "Culture and Traditions", progress: 0, color: "bg-pink-500" },
      ];

  return (
    <div className="card-clay-static p-6">
      <h2 className="text-lg font-bold font-nunito mb-6 flex items-center gap-2">
        <Trophy className="h-5 w-5 text-amber-500" />
        Topic Progress
      </h2>
      <div className="space-y-4">
        {topicProgress.map(({ topic, progress, color }) => (
          <div key={topic}>
            <div className="flex justify-between text-sm mb-2">
              <span className="font-medium">{topic}</span>
              <span className="text-muted-foreground">{progress}%</span>
            </div>
            <div className="h-2 bg-muted rounded-full overflow-hidden">
              <div
                className={`h-full ${color} rounded-full transition-all duration-500`}
                style={{ width: `${progress}%` }}
              />
            </div>
          </div>
        ))}
      </div>
      <Link
        href="/progress"
        className="flex items-center gap-1 text-primary text-sm font-medium mt-6 hover:underline"
      >
        View all topics
        <ArrowRight className="h-4 w-4" />
      </Link>
    </div>
  );
}

function TopicsProgressEmpty() {
  const defaultTopics = [
    { topic: "British History", progress: 0, color: "bg-amber-500" },
    { topic: "UK Government", progress: 0, color: "bg-blue-500" },
    { topic: "Laws and Rights", progress: 0, color: "bg-purple-500" },
    { topic: "Culture and Traditions", progress: 0, color: "bg-pink-500" },
  ];

  return (
    <div className="card-clay-static p-6">
      <h2 className="text-lg font-bold font-nunito mb-6 flex items-center gap-2">
        <Trophy className="h-5 w-5 text-amber-500" />
        Topic Progress
      </h2>
      <div className="space-y-4">
        {defaultTopics.map(({ topic, progress, color }) => (
          <div key={topic}>
            <div className="flex justify-between text-sm mb-2">
              <span className="font-medium">{topic}</span>
              <span className="text-muted-foreground">{progress}%</span>
            </div>
            <div className="h-2 bg-muted rounded-full overflow-hidden">
              <div
                className={`h-full ${color} rounded-full transition-all duration-500`}
                style={{ width: `${progress}%` }}
              />
            </div>
          </div>
        ))}
      </div>
      <Link
        href="/progress"
        className="flex items-center gap-1 text-primary text-sm font-medium mt-6 hover:underline"
      >
        View all topics
        <ArrowRight className="h-4 w-4" />
      </Link>
    </div>
  );
}

// Review Banner
async function ReviewBanner({ userId }: { userId: string | null }) {
  let dueReviews = 0;

  if (userId) {
    const { env } = getRequestContext();
    const db = getDb(env.DB);
    const now = new Date().toISOString();

    const dueCount = await db
      .select({ count: sql<number>`COUNT(*)` })
      .from(srRecords)
      .where(and(
        eq(srRecords.userId, userId),
        sql`${srRecords.nextReviewAt} <= ${now}`
      ));

    dueReviews = dueCount[0]?.count ?? 0;
  }

  return (
    <div className="card-clay-static bg-gradient-primary text-white mt-6 p-6">
      <div className="flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="bg-white/20 p-3 rounded-xl">
            <Clock className="h-8 w-8" />
          </div>
          <div>
            <h2 className="text-lg font-bold font-nunito">Today&apos;s Review</h2>
            <p className="text-white/80">
              {dueReviews > 0
                ? `${dueReviews} questions due for review`
                : "No questions due - great job staying on top of reviews!"}
            </p>
          </div>
        </div>
        <Button asChild variant="secondary" className="btn-clay shrink-0">
          <Link href="/review">
            {dueReviews > 0 ? "Start Review" : "Practice More"}
          </Link>
        </Button>
      </div>
    </div>
  );
}

// Skeleton Components
function StatsCardSkeleton() {
  return (
    <div className="card-clay-static p-6">
      <Skeleton className="h-6 w-32 mb-6" />
      <div className="grid grid-cols-2 gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="bg-muted/50 rounded-xl p-4">
            <Skeleton className="h-4 w-24 mb-2" />
            <Skeleton className="h-8 w-16" />
          </div>
        ))}
      </div>
    </div>
  );
}

function TopicsProgressSkeleton() {
  return (
    <div className="card-clay-static p-6">
      <Skeleton className="h-6 w-32 mb-6" />
      <div className="space-y-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i}>
            <div className="flex justify-between mb-2">
              <Skeleton className="h-4 w-32" />
              <Skeleton className="h-4 w-8" />
            </div>
            <Skeleton className="h-2 w-full rounded-full" />
          </div>
        ))}
      </div>
      <Skeleton className="h-4 w-28 mt-6" />
    </div>
  );
}

function ReviewBannerSkeleton() {
  return (
    <div className="card-clay-static mt-6 p-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Skeleton className="h-14 w-14 rounded-xl" />
          <div>
            <Skeleton className="h-6 w-32 mb-2" />
            <Skeleton className="h-4 w-48" />
          </div>
        </div>
        <Skeleton className="h-10 w-28 rounded-xl" />
      </div>
    </div>
  );
}
