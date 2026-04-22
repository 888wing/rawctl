// src/app/api/user/answers/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { auth } from '@clerk/nextjs/server';
import { getDb } from '@/lib/db';
import { userAnswers } from '@/lib/db/schema';

export const runtime = 'edge';

export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const { questionId, selectedIndex, isCorrect, timeSpentMs } = await request.json() as { questionId?: string; selectedIndex?: number; isCorrect?: boolean; timeSpentMs?: number };

    if (!questionId || selectedIndex === undefined || isCorrect === undefined) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    const [answer] = await db
      .insert(userAnswers)
      .values({
        userId,
        questionId,
        selectedIndex,
        isCorrect,
        timeSpentMs: timeSpentMs || null,
      })
      .returning();

    return NextResponse.json({ success: true, answer });
  } catch (error) {
    console.error('Error saving answer:', error);
    return NextResponse.json(
      { error: 'Failed to save answer' },
      { status: 500 }
    );
  }
}
