import { Suspense } from "react";
import { auth } from "@clerk/nextjs/server";
import Link from "next/link";
import {
  Trophy,
  Target,
  TrendingUp,
  Calendar,
  Clock,
  CheckCircle2,
  Flame,
  BookOpen,
  ArrowRight,
  Sparkles,
  Award,
  Star,
  BarChart3,
  XCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { getRequestContext } from "@cloudflare/next-on-pages";
import { getDb } from "@/lib/db";
import { userAnswers, questions, mockExams } from "@/lib/db/schema";
import { eq, sql, and, gte, desc } from "drizzle-orm";

export const runtime = "edge";

export default async function ProgressPage() {
  const { userId } = await auth();

  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-8 max-w-5xl">
        {/* Header */}
        <div className="text-center mb-8">
          <Badge variant="outline" className="mb-4">Progress Tracking</Badge>
          <h1 className="text-3xl md:text-4xl font-bold font-nunito text-gray-900 mb-3">
            Your Learning Journey
          </h1>
          <p className="text-muted-foreground text-lg">
            Track your progress towards passing the Life in the UK test
          </p>
        </div>

        {/* Overall Progress Card */}
        <Suspense fallback={<OverallProgressSkeleton />}>
          <OverallProgressCard userId={userId} />
        </Suspense>

        {/* Stats Grid */}
        <Suspense fallback={<StatsGridSkeleton />}>
          <StatsGrid userId={userId} />
        </Suspense>

        {/* Topic Progress */}
        <Suspense fallback={<TopicProgressSkeleton />}>
          <TopicProgressSection userId={userId} />
        </Suspense>

        {/* Recent Activity */}
        <Suspense fallback={<RecentActivitySkeleton />}>
          <RecentActivitySection userId={userId} />
        </Suspense>

        {/* Call to Action */}
        <div className="card-clay-static bg-gradient-primary text-white p-6 md:p-8 mt-8">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="text-center md:text-left">
              <h2 className="text-xl md:text-2xl font-bold font-nunito mb-2">
                Ready to Continue?
              </h2>
              <p className="text-white/80">
                Keep practicing to improve your accuracy and build confidence.
              </p>
            </div>
            <div className="flex gap-4">
              <Button asChild variant="secondary" className="btn-clay">
                <Link href="/practice">
                  <Sparkles className="h-4 w-4 mr-2" />
                  Practice
                </Link>
              </Button>
              <Button asChild variant="secondary" className="btn-clay">
                <Link href="/mock-exam">
                  <Target className="h-4 w-4 mr-2" />
                  Mock Exam
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}

// Overall Progress Card
async function OverallProgressCard({ userId }: { userId: string | null }) {
  let overallProgress = 0;

  if (userId) {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Count unique questions answered correctly
    const correctResult = await db
      .select({
        uniqueCorrect: sql<number>`COUNT(DISTINCT ${userAnswers.questionId})`,
      })
      .from(userAnswers)
      .where(and(eq(userAnswers.userId, userId), eq(userAnswers.isCorrect, true)));

    // Count total available questions
    const totalResult = await db
      .select({
        totalQuestions: sql<number>`COUNT(*)`,
      })
      .from(questions);

    const uniqueCorrect = correctResult[0]?.uniqueCorrect ?? 0;
    const totalQuestions = totalResult[0]?.totalQuestions ?? 0;

    overallProgress = totalQuestions > 0
      ? Math.round((uniqueCorrect / totalQuestions) * 100)
      : 0;
  }

  const estimatedReadiness = overallProgress >= 75 ? "Ready" : overallProgress >= 50 ? "Almost There" : "Keep Practicing";
  const readinessColor = overallProgress >= 75 ? "text-success-600" : overallProgress >= 50 ? "text-amber-600" : "text-primary";

  return (
    <div className="card-clay-static p-6 md:p-8 mb-8">
      <div className="flex flex-col md:flex-row md:items-center gap-6">
        {/* Progress Circle */}
        <div className="relative mx-auto md:mx-0">
          <div className="w-32 h-32 rounded-full bg-muted/50 flex items-center justify-center">
            <div className="w-24 h-24 rounded-full bg-white shadow-clay-sm flex items-center justify-center">
              <div className="text-center">
                <span className="text-3xl font-bold font-nunito text-primary">{overallProgress}%</span>
                <p className="text-xs text-muted-foreground">Overall</p>
              </div>
            </div>
          </div>
          <div
            className="absolute inset-0 rounded-full border-4 border-primary/20"
            style={{
              background: `conic-gradient(rgb(99 102 241) ${overallProgress * 3.6}deg, transparent 0deg)`,
              maskImage: 'radial-gradient(transparent 60%, black 61%)',
              WebkitMaskImage: 'radial-gradient(transparent 60%, black 61%)',
            }}
          />
        </div>

        {/* Info */}
        <div className="flex-1 text-center md:text-left">
          <div className="flex items-center justify-center md:justify-start gap-2 mb-2">
            <Trophy className="h-6 w-6 text-amber-500" />
            <h2 className="text-xl font-bold font-nunito">Test Readiness</h2>
          </div>
          <p className={`text-lg font-semibold ${readinessColor} mb-3`}>
            {estimatedReadiness}
          </p>
          <p className="text-muted-foreground text-sm mb-4">
            You need to score 75% or higher to pass the official Life in the UK test.
            {overallProgress < 75 && " Keep practicing to improve your accuracy!"}
          </p>
          <div className="flex flex-wrap gap-2 justify-center md:justify-start">
            <Badge variant="outline" className="bg-muted/50">
              <Target className="h-3 w-3 mr-1" />
              75% to pass
            </Badge>
            <Badge variant="outline" className="bg-muted/50">
              <BookOpen className="h-3 w-3 mr-1" />
              24 questions
            </Badge>
            <Badge variant="outline" className="bg-muted/50">
              <Clock className="h-3 w-3 mr-1" />
              45 minutes
            </Badge>
          </div>
        </div>
      </div>
    </div>
  );
}

// Stats Grid
async function StatsGrid({ userId }: { userId: string | null }) {
  let stats = {
    totalQuestions: 0,
    correctAnswers: 0,
    accuracy: 0,
    mockExamsPassed: 0,
    mockExamsTaken: 0,
    studyStreak: 0,
  };

  if (userId) {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Total questions answered and accuracy
    const totalStats = await db
      .select({
        totalAnswered: sql<number>`COUNT(*)`,
        correctAnswers: sql<number>`SUM(CASE WHEN ${userAnswers.isCorrect} THEN 1 ELSE 0 END)`,
      })
      .from(userAnswers)
      .where(eq(userAnswers.userId, userId));

    const totalAnswered = totalStats[0]?.totalAnswered ?? 0;
    const correctAnswers = totalStats[0]?.correctAnswers ?? 0;

    // Mock exam stats
    const examStats = await db
      .select({
        totalExams: sql<number>`COUNT(*)`,
        passedExams: sql<number>`SUM(CASE WHEN ${mockExams.passed} THEN 1 ELSE 0 END)`,
      })
      .from(mockExams)
      .where(eq(mockExams.userId, userId));

    const totalExams = examStats[0]?.totalExams ?? 0;
    const passedExams = examStats[0]?.passedExams ?? 0;

    // Calculate study streak (consecutive days with at least one answer)
    const today = new Date();
    const thirtyDaysAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);

    const recentDays = await db
      .select({
        date: sql<string>`DATE(${userAnswers.createdAt})`,
      })
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
    const dates = recentDays.map((r) => r.date);
    for (let i = 0; i < 30; i++) {
      const checkDate = new Date(today.getTime() - i * 24 * 60 * 60 * 1000);
      const checkDateStr = checkDate.toISOString().split("T")[0];
      if (dates.includes(checkDateStr)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    stats = {
      totalQuestions: totalAnswered,
      correctAnswers,
      accuracy: totalAnswered > 0 ? Math.round((correctAnswers / totalAnswered) * 100) : 0,
      mockExamsPassed: passedExams,
      mockExamsTaken: totalExams,
      studyStreak: streak,
    };
  }

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <StatCard
        icon={BarChart3}
        label="Questions Answered"
        value={stats.totalQuestions.toString()}
        color="bg-primary/10 text-primary"
      />
      <StatCard
        icon={CheckCircle2}
        label="Accuracy Rate"
        value={`${stats.accuracy}%`}
        color="bg-success-100 text-success-600"
      />
      <StatCard
        icon={Award}
        label="Mock Exams Passed"
        value={`${stats.mockExamsPassed}/${stats.mockExamsTaken}`}
        color="bg-purple-100 text-purple-600"
      />
      <StatCard
        icon={Flame}
        label="Study Streak"
        value={`${stats.studyStreak} days`}
        color="bg-amber-100 text-amber-600"
        highlight={stats.studyStreak >= 7}
      />
    </div>
  );
}

function StatCard({
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
    <div className={`card-clay-static p-4 ${highlight ? 'ring-2 ring-amber-400' : ''}`}>
      <div className={`w-10 h-10 rounded-xl ${color} flex items-center justify-center mb-3`}>
        <Icon className="h-5 w-5" />
      </div>
      <div className="text-2xl font-bold font-nunito">{value}</div>
      <div className="text-sm text-muted-foreground">{label}</div>
    </div>
  );
}

// Topic config from centralized source
import { TOPICS } from "@/lib/topics";

// Build TOPIC_CONFIG from centralized topics data
const TOPIC_CONFIG: Record<string, { color: string; icon: React.ElementType }> = Object.fromEntries(
  TOPICS.map((t) => [t.dbName, { color: t.progressColor, icon: t.icon }])
);

const DEFAULT_TOPIC_CONFIG = { color: "bg-gray-500", icon: BookOpen };

// Topic Progress Section
async function TopicProgressSection({ userId }: { userId: string | null }) {
  let topics: {
    name: string;
    progress: number;
    questionsAnswered: number;
    totalQuestions: number;
    color: string;
    icon: React.ElementType;
  }[] = [];

  if (userId) {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Get total questions per topic
    const totalPerTopic = await db
      .select({
        topic: questions.topic,
        count: sql<number>`COUNT(*)`,
      })
      .from(questions)
      .groupBy(questions.topic);

    // Get per-topic accuracy (unique correct questions per topic)
    const answeredPerTopic = await db
      .select({
        topic: questions.topic,
        total: sql<number>`COUNT(*)`,
        correct: sql<number>`SUM(CASE WHEN ${userAnswers.isCorrect} THEN 1 ELSE 0 END)`,
      })
      .from(userAnswers)
      .innerJoin(questions, eq(userAnswers.questionId, questions.id))
      .where(eq(userAnswers.userId, userId))
      .groupBy(questions.topic);

    // Build a map of answered stats by topic
    const answeredMap = new Map(
      answeredPerTopic.map((t) => [t.topic, { total: t.total, correct: t.correct }])
    );

    topics = totalPerTopic.map((t) => {
      const answered = answeredMap.get(t.topic);
      const questionsAnswered = answered?.total ?? 0;
      const correctAnswers = answered?.correct ?? 0;
      const progress = questionsAnswered > 0
        ? Math.round((correctAnswers / questionsAnswered) * 100)
        : 0;
      const config = TOPIC_CONFIG[t.topic] ?? DEFAULT_TOPIC_CONFIG;

      return {
        name: t.topic,
        progress,
        questionsAnswered,
        totalQuestions: t.count,
        color: config.color,
        icon: config.icon,
      };
    });
  }

  // If no topics found (no questions in DB or not logged in), show default empty state
  if (topics.length === 0) {
    const defaultTopics = Object.entries(TOPIC_CONFIG).map(([name, config]) => ({
      name,
      progress: 0,
      questionsAnswered: 0,
      totalQuestions: 0,
      color: config.color,
      icon: config.icon,
    }));
    topics = defaultTopics;
  }

  return (
    <div className="card-clay-static p-6 md:p-8 mb-8">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <BookOpen className="h-5 w-5 text-primary" />
          <h2 className="text-xl font-bold font-nunito">Topic Progress</h2>
        </div>
        <Link
          href="/practice"
          className="text-sm text-primary font-medium hover:underline flex items-center gap-1"
        >
          Practice by topic
          <ArrowRight className="h-4 w-4" />
        </Link>
      </div>

      <div className="space-y-5">
        {topics.map((topic) => {
          const Icon = topic.icon;
          return (
            <div key={topic.name}>
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className={`w-8 h-8 rounded-lg ${topic.color} bg-opacity-20 flex items-center justify-center`}>
                    <Icon className={`h-4 w-4 ${topic.color.replace('bg-', 'text-')}`} />
                  </div>
                  <span className="font-medium text-sm">{topic.name}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-xs text-muted-foreground">
                    {topic.questionsAnswered}/{topic.totalQuestions}
                  </span>
                  <span className="text-sm font-semibold w-10 text-right">{topic.progress}%</span>
                </div>
              </div>
              <div className="h-2 bg-muted rounded-full overflow-hidden">
                <div
                  className={`h-full ${topic.color} rounded-full transition-all duration-500`}
                  style={{ width: `${topic.progress}%` }}
                />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// Recent Activity Section
async function RecentActivitySection({ userId }: { userId: string | null }) {
  let activities: {
    type: string;
    description: string;
    timestamp: string;
    icon: React.ElementType;
    color: string;
  }[] = [];

  if (userId) {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Get recent answers with question info
    const recentAnswers = await db
      .select({
        isCorrect: userAnswers.isCorrect,
        createdAt: userAnswers.createdAt,
        questionText: questions.question,
        topic: questions.topic,
      })
      .from(userAnswers)
      .innerJoin(questions, eq(userAnswers.questionId, questions.id))
      .where(eq(userAnswers.userId, userId))
      .orderBy(desc(userAnswers.createdAt))
      .limit(10);

    activities = recentAnswers.map((answer) => {
      const isCorrect = answer.isCorrect;
      const topicShort = answer.topic.length > 30
        ? answer.topic.substring(0, 30) + "..."
        : answer.topic;

      return {
        type: isCorrect ? "correct" : "incorrect",
        description: isCorrect
          ? `Correctly answered a question in "${topicShort}"`
          : `Answered a question in "${topicShort}"`,
        timestamp: formatTimestamp(answer.createdAt),
        icon: isCorrect ? CheckCircle2 : XCircle,
        color: isCorrect ? "bg-green-500" : "bg-red-500",
      };
    });
  }

  if (activities.length === 0) {
    return (
      <div className="card-clay-static p-6 md:p-8">
        <div className="flex items-center gap-2 mb-6">
          <Clock className="h-5 w-5 text-muted-foreground" />
          <h2 className="text-xl font-bold font-nunito">Recent Activity</h2>
        </div>
        <div className="text-center py-8">
          <div className="bg-muted/50 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
            <BookOpen className="h-8 w-8 text-muted-foreground" />
          </div>
          <h3 className="font-semibold mb-2">No Activity Yet</h3>
          <p className="text-muted-foreground text-sm mb-4">
            Start practicing to see your activity history here.
          </p>
          <Button asChild variant="outline" className="shadow-clay-sm">
            <Link href="/practice">
              <Sparkles className="h-4 w-4 mr-2" />
              Start Practicing
            </Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="card-clay-static p-6 md:p-8">
      <div className="flex items-center gap-2 mb-6">
        <Clock className="h-5 w-5 text-muted-foreground" />
        <h2 className="text-xl font-bold font-nunito">Recent Activity</h2>
      </div>
      <div className="space-y-4">
        {activities.map((activity, index) => {
          const Icon = activity.icon;
          return (
            <div key={index} className="flex items-center gap-4 p-3 bg-muted/30 rounded-xl">
              <div className={`w-10 h-10 rounded-xl ${activity.color} flex items-center justify-center`}>
                <Icon className="h-5 w-5 text-white" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-sm">{activity.description}</p>
                <p className="text-xs text-muted-foreground">{activity.timestamp}</p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// Helper: format a timestamp string into a human-readable relative time
function formatTimestamp(createdAt: string | null): string {
  if (!createdAt) return "Unknown";

  const date = new Date(createdAt);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMinutes = Math.floor(diffMs / (1000 * 60));
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffMinutes < 1) return "Just now";
  if (diffMinutes < 60) return `${diffMinutes} minute${diffMinutes === 1 ? "" : "s"} ago`;
  if (diffHours < 24) return `${diffHours} hour${diffHours === 1 ? "" : "s"} ago`;
  if (diffDays < 7) return `${diffDays} day${diffDays === 1 ? "" : "s"} ago`;

  return date.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

// Skeleton Components
function OverallProgressSkeleton() {
  return (
    <div className="card-clay-static p-6 md:p-8 mb-8">
      <div className="flex flex-col md:flex-row md:items-center gap-6">
        <Skeleton className="w-32 h-32 rounded-full mx-auto md:mx-0" />
        <div className="flex-1 text-center md:text-left">
          <Skeleton className="h-6 w-40 mb-2 mx-auto md:mx-0" />
          <Skeleton className="h-5 w-24 mb-3 mx-auto md:mx-0" />
          <Skeleton className="h-4 w-full max-w-md mb-4" />
          <div className="flex gap-2 justify-center md:justify-start">
            <Skeleton className="h-6 w-24" />
            <Skeleton className="h-6 w-24" />
            <Skeleton className="h-6 w-24" />
          </div>
        </div>
      </div>
    </div>
  );
}

function StatsGridSkeleton() {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="card-clay-static p-4">
          <Skeleton className="w-10 h-10 rounded-xl mb-3" />
          <Skeleton className="h-8 w-16 mb-1" />
          <Skeleton className="h-4 w-24" />
        </div>
      ))}
    </div>
  );
}

function TopicProgressSkeleton() {
  return (
    <div className="card-clay-static p-6 md:p-8 mb-8">
      <Skeleton className="h-6 w-40 mb-6" />
      <div className="space-y-5">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i}>
            <div className="flex items-center justify-between mb-2">
              <Skeleton className="h-4 w-48" />
              <Skeleton className="h-4 w-12" />
            </div>
            <Skeleton className="h-2 w-full rounded-full" />
          </div>
        ))}
      </div>
    </div>
  );
}

function RecentActivitySkeleton() {
  return (
    <div className="card-clay-static p-6 md:p-8">
      <Skeleton className="h-6 w-40 mb-6" />
      <div className="space-y-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="flex items-center gap-4 p-3 bg-muted/30 rounded-xl">
            <Skeleton className="w-10 h-10 rounded-xl" />
            <div className="flex-1">
              <Skeleton className="h-4 w-48 mb-1" />
              <Skeleton className="h-3 w-24" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
