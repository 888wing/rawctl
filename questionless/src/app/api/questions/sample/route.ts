// src/app/api/questions/sample/route.ts
// Public endpoint - no auth required - returns 5 random questions for free trial
import { NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { questions } from '@/lib/db/schema';
import { eq, sql } from 'drizzle-orm';

export const runtime = 'edge';

export async function GET() {
  try {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    // Get 5 random verified questions for free trial
    const result = await db
      .select()
      .from(questions)
      .where(eq(questions.verified, true))
      .orderBy(sql`RANDOM()`)
      .limit(5);

    const parsed = result.map(q => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({
      questions: parsed,
      isFreeTrial: true,
      limit: 5,
      message: 'Sign up for unlimited practice!',
    });
  } catch (error) {
    console.error('Error fetching sample questions:', error);
    return NextResponse.json(
      { error: 'Failed to fetch questions' },
      { status: 500 }
    );
  }
}
