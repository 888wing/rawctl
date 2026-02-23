// src/app/api/questions/topic/[slug]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { questions } from '@/lib/db/schema';
import { eq, and } from 'drizzle-orm';
import { SLUG_TO_DB } from '@/lib/topics';
import { getExamSlugToDb } from '@/lib/exams';

export const runtime = 'edge';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  try {
    const { slug } = await params;
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const { searchParams } = new URL(request.url);
    const examSlug = searchParams.get('exam');
    const limit = parseInt(searchParams.get('limit') || '20');
    const verified = searchParams.get('verified') !== 'false';

    // Use exam-specific topic map if exam param provided, otherwise default
    const topicMap = examSlug ? getExamSlugToDb(examSlug) : SLUG_TO_DB;
    const topicName = topicMap[slug];
    if (!topicName) {
      return NextResponse.json(
        { error: `Unknown topic: ${slug}` },
        { status: 404 }
      );
    }

    const conditions = [eq(questions.topic, topicName)];
    if (verified) {
      conditions.push(eq(questions.verified, true));
    }
    // Filter by exam if specified
    if (examSlug) {
      conditions.push(eq(questions.exam, examSlug));
    }

    const result = await db
      .select()
      .from(questions)
      .where(and(...conditions))
      .limit(limit);

    const parsed = result.map(q => ({
      ...q,
      options: JSON.parse(q.options),
    }));

    return NextResponse.json({
      topic: topicName,
      slug,
      questions: parsed,
      count: parsed.length,
    });
  } catch (error) {
    console.error('Error fetching topic questions:', error);
    return NextResponse.json(
      { error: 'Failed to fetch questions' },
      { status: 500 }
    );
  }
}
