import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { auth } from '@clerk/nextjs/server';
import { getDb } from '@/lib/db';
import { srRecords, questions } from '@/lib/db/schema';
import { eq, and, sql } from 'drizzle-orm';

export const runtime = 'edge';

// GET: Get questions due for review
export async function GET(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);
    const now = new Date().toISOString();

    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '20', 10);

    // Get SR records that are due for review
    const dueRecords = await db
      .select({
        questionId: srRecords.questionId,
        easeFactor: srRecords.easeFactor,
        intervalDays: srRecords.intervalDays,
        repetitions: srRecords.repetitions,
        nextReviewAt: srRecords.nextReviewAt,
      })
      .from(srRecords)
      .where(
        and(
          eq(srRecords.userId, userId),
          sql`${srRecords.nextReviewAt} <= ${now}`
        )
      )
      .orderBy(srRecords.nextReviewAt)
      .limit(limit);

    if (dueRecords.length === 0) {
      return NextResponse.json({ questions: [], total: 0 });
    }

    // Get the actual question data
    const questionIds = dueRecords.map(r => r.questionId);
    const dueQuestions = await db
      .select()
      .from(questions)
      .where(sql`${questions.id} IN (${sql.join(questionIds.map(id => sql`${id}`), sql`, `)})`);

    const parsedQuestions = dueQuestions.map(q => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({
      questions: parsedQuestions,
      total: dueRecords.length,
    });
  } catch (error) {
    console.error('Error fetching due reviews:', error);
    return NextResponse.json({ error: 'Failed to fetch reviews' }, { status: 500 });
  }
}
