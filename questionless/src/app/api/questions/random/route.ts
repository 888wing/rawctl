// src/app/api/questions/random/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { questions } from '@/lib/db/schema';
import { eq, sql } from 'drizzle-orm';

export const runtime = 'edge';

export async function GET(request: NextRequest) {
  try {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const { searchParams } = new URL(request.url);
    const count = Math.min(parseInt(searchParams.get('count') || '10'), 50);

    // Get random verified questions
    const result = await db
      .select()
      .from(questions)
      .where(eq(questions.verified, true))
      .orderBy(sql`RANDOM()`)
      .limit(count);

    const parsed = result.map(q => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({ questions: parsed });
  } catch (error) {
    console.error('Error fetching random questions:', error);
    return NextResponse.json(
      { error: 'Failed to fetch questions' },
      { status: 500 }
    );
  }
}
