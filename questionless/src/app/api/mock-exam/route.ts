// src/app/api/mock-exam/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { auth } from '@clerk/nextjs/server';
import { getDb } from '@/lib/db';
import { mockExams, questions } from '@/lib/db/schema';
import { eq, sql } from 'drizzle-orm';

export const runtime = 'edge';

export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Get 24 random verified questions
    const randomQuestions = await db
      .select()
      .from(questions)
      .where(eq(questions.verified, true))
      .orderBy(sql`RANDOM()`)
      .limit(24);

    if (randomQuestions.length < 24) {
      return NextResponse.json(
        { error: 'Not enough questions available' },
        { status: 400 }
      );
    }

    const questionIds = randomQuestions.map(q => q.id);

    // Create mock exam record
    const examId = crypto.randomUUID();
    const [exam] = await db
      .insert(mockExams)
      .values({
        id: examId,
        userId,
        questionIds: JSON.stringify(questionIds),
        answers: JSON.stringify([]),
        score: 0,
        passed: false,
        startedAt: new Date().toISOString(),
      })
      .returning();

    // Parse questions for response
    const parsedQuestions = randomQuestions.map(q => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({
      examId: exam.id,
      questions: parsedQuestions,
      timeLimit: 45 * 60, // 45 minutes in seconds
    });
  } catch (error) {
    console.error('Error creating mock exam:', error);
    return NextResponse.json(
      { error: 'Failed to create exam' },
      { status: 500 }
    );
  }
}
