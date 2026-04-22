// src/app/api/user/stats/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { auth } from '@clerk/nextjs/server';
import { getDb } from '@/lib/db';
import { userAnswers, questions, mockExams } from '@/lib/db/schema';
import { eq, sql, and, gte } from 'drizzle-orm';

export const runtime = 'edge';

export async function GET(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Get total questions answered and accuracy
    const totalStats = await db
      .select({
        totalAnswered: sql<number>`COUNT(*)`,
        correctAnswers: sql<number>`SUM(CASE WHEN ${userAnswers.isCorrect} THEN 1 ELSE 0 END)`,
      })
      .from(userAnswers)
      .where(eq(userAnswers.userId, userId));

    const { totalAnswered, correctAnswers } = totalStats[0] || { totalAnswered: 0, correctAnswers: 0 };
    const overallAccuracy = totalAnswered > 0 ? Math.round((correctAnswers / totalAnswered) * 100) : 0;

    // Get per-topic accuracy
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

    const topicAccuracy = topicStats.map(t => ({
      topic: t.topic,
      total: t.total,
      correct: t.correct,
      accuracy: t.total > 0 ? Math.round((t.correct / t.total) * 100) : 0,
    }));

    // Get mock exam stats
    const examStats = await db
      .select({
        totalExams: sql<number>`COUNT(*)`,
        passedExams: sql<number>`SUM(CASE WHEN ${mockExams.passed} THEN 1 ELSE 0 END)`,
        avgScore: sql<number>`AVG(${mockExams.score})`,
      })
      .from(mockExams)
      .where(eq(mockExams.userId, userId));

    const { totalExams, passedExams, avgScore } = examStats[0] || { totalExams: 0, passedExams: 0, avgScore: 0 };

    // Calculate study streak (days with at least one answer)
    const today = new Date();
    const thirtyDaysAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);

    const recentActivity = await db
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

    // Calculate streak
    let streak = 0;
    const dates = recentActivity.map(r => r.date);

    for (let i = 0; i < 30; i++) {
      const checkDate = new Date(today.getTime() - i * 24 * 60 * 60 * 1000);
      const checkDateStr = checkDate.toISOString().split('T')[0];
      if (dates.includes(checkDateStr)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    return NextResponse.json({
      totalAnswered,
      correctAnswers,
      overallAccuracy,
      topicAccuracy,
      mockExams: {
        total: totalExams,
        passed: passedExams,
        passRate: totalExams > 0 ? Math.round((passedExams / totalExams) * 100) : 0,
        avgScore: Math.round(avgScore || 0),
      },
      streak,
    });
  } catch (error) {
    console.error('Error fetching user stats:', error);
    return NextResponse.json(
      { error: 'Failed to fetch stats' },
      { status: 500 }
    );
  }
}
