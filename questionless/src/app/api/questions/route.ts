import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { questions } from '@/lib/db/schema';
import { eq, and } from 'drizzle-orm';

export const runtime = 'edge';

export async function GET(request: NextRequest) {
  try {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const { searchParams } = new URL(request.url);
    const topic = searchParams.get('topic');
    const limit = parseInt(searchParams.get('limit') || '50', 10);
    const verified = searchParams.get('verified');

    // Build conditions array for filtering
    const conditions = [];

    if (topic) {
      conditions.push(eq(questions.topic, topic));
    }

    if (verified === 'true') {
      conditions.push(eq(questions.verified, true));
    }

    // Execute query with optional filters
    let result;
    if (conditions.length > 0) {
      result = await db
        .select()
        .from(questions)
        .where(and(...conditions))
        .limit(limit);
    } else {
      result = await db
        .select()
        .from(questions)
        .limit(limit);
    }

    // Parse options JSON for each question
    const parsed = result.map((q) => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({ questions: parsed });
  } catch (error) {
    console.error('Error fetching questions:', error);
    return NextResponse.json(
      { error: 'Failed to fetch questions' },
      { status: 500 }
    );
  }
}
