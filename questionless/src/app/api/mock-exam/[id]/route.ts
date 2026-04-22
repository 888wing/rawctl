// src/app/api/mock-exam/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { auth } from '@clerk/nextjs/server';
import { getDb } from '@/lib/db';
import { mockExams, questions } from '@/lib/db/schema';
import { eq, and, inArray } from 'drizzle-orm';

export const runtime = 'edge';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id } = await params;
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const [exam] = await db
      .select()
      .from(mockExams)
      .where(and(eq(mockExams.id, id), eq(mockExams.userId, userId)));

    if (!exam) {
      return NextResponse.json({ error: 'Exam not found' }, { status: 404 });
    }

    // Get questions for this exam
    const questionIds = JSON.parse(exam.questionIds);
    const examQuestions = await db
      .select()
      .from(questions)
      .where(inArray(questions.id, questionIds));

    const parsedQuestions = examQuestions.map(q => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({
      ...exam,
      questionIds,
      answers: exam.answers ? JSON.parse(exam.answers) : [],
      questions: parsedQuestions,
    });
  } catch (error) {
    console.error('Error fetching exam:', error);
    return NextResponse.json({ error: 'Failed to fetch exam' }, { status: 500 });
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id } = await params;
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const body = await request.json() as { answers?: { questionId: string; selectedIndex: number }[]; completed?: boolean };
    const { answers, completed } = body;

    // Get current exam
    const [exam] = await db
      .select()
      .from(mockExams)
      .where(and(eq(mockExams.id, id), eq(mockExams.userId, userId)));

    if (!exam) {
      return NextResponse.json({ error: 'Exam not found' }, { status: 404 });
    }

    const updateData: Record<string, unknown> = {};

    if (answers) {
      updateData.answers = JSON.stringify(answers);
    }

    if (completed) {
      // Calculate score
      const questionIds = JSON.parse(exam.questionIds);
      const examQuestions = await db
        .select()
        .from(questions)
        .where(inArray(questions.id, questionIds));

      let correct = 0;
      for (const answer of (answers ?? [])) {
        const question = examQuestions.find(q => q.id === answer.questionId);
        if (question && answer.selectedIndex === question.correctIndex) {
          correct++;
        }
      }

      const score = Math.round((correct / 24) * 100);
      updateData.score = score;
      updateData.passed = score >= 75;
      updateData.completedAt = new Date().toISOString();
    }

    const [updated] = await db
      .update(mockExams)
      .set(updateData)
      .where(eq(mockExams.id, id))
      .returning();

    return NextResponse.json({
      ...updated,
      answers: updated.answers ? JSON.parse(updated.answers) : [],
    });
  } catch (error) {
    console.error('Error updating exam:', error);
    return NextResponse.json({ error: 'Failed to update exam' }, { status: 500 });
  }
}
