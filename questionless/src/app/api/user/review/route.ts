import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { auth } from '@clerk/nextjs/server';
import { getDb } from '@/lib/db';
import { srRecords } from '@/lib/db/schema';
import { eq, and } from 'drizzle-orm';
import { calculateNextReview, answerToQuality } from '@/lib/sr-algorithm';

export const runtime = 'edge';

// POST: Update SR record after answering a question
export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const { questionId, isCorrect, timeSpentMs } = await request.json() as { questionId?: string; isCorrect?: boolean; timeSpentMs?: number };

    if (!questionId || isCorrect === undefined) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Get existing SR record
    const [existing] = await db
      .select()
      .from(srRecords)
      .where(and(eq(srRecords.userId, userId), eq(srRecords.questionId, questionId)))
      .limit(1);

    const quality = answerToQuality(isCorrect, timeSpentMs);
    const currentState = existing
      ? {
          easeFactor: existing.easeFactor ?? 2.5,
          intervalDays: existing.intervalDays ?? 1,
          repetitions: existing.repetitions ?? 0,
          nextReviewAt: existing.nextReviewAt ? new Date(existing.nextReviewAt) : new Date(),
        }
      : null;

    const nextState = calculateNextReview(currentState, quality);

    if (existing) {
      // Update existing record
      await db
        .update(srRecords)
        .set({
          easeFactor: nextState.easeFactor,
          intervalDays: nextState.intervalDays,
          repetitions: nextState.repetitions,
          nextReviewAt: nextState.nextReviewAt.toISOString(),
        })
        .where(eq(srRecords.id, existing.id));
    } else {
      // Create new record
      await db
        .insert(srRecords)
        .values({
          userId,
          questionId,
          easeFactor: nextState.easeFactor,
          intervalDays: nextState.intervalDays,
          repetitions: nextState.repetitions,
          nextReviewAt: nextState.nextReviewAt.toISOString(),
        });
    }

    return NextResponse.json({
      success: true,
      nextReviewAt: nextState.nextReviewAt.toISOString(),
      intervalDays: nextState.intervalDays,
    });
  } catch (error) {
    console.error('Error updating SR record:', error);
    return NextResponse.json({ error: 'Failed to update review' }, { status: 500 });
  }
}
