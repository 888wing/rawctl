import { getDefaultExam, getExamSlugToDb, getExamDbToSlug, getExamDbToColor, getExamTopicSlugs } from "./exams";

/**
 * Backwards-compatible topic exports.
 * These reference the default exam (Life in the UK) topics.
 * New code should use exams.ts directly for multi-exam support.
 */

const defaultExam = getDefaultExam();

export const TOPICS = defaultExam.topics;

export type TopicSlug = (typeof TOPICS)[number]["slug"];

/** Map from URL slug to DB topic name (default exam) */
export const SLUG_TO_DB: Record<string, string> = getExamSlugToDb(defaultExam.slug);

/** Map from DB topic name to URL slug (default exam) */
export const DB_TO_SLUG: Record<string, string> = getExamDbToSlug(defaultExam.slug);

/** Map from DB topic name to progress bar color (default exam) */
export const DB_TO_COLOR: Record<string, string> = getExamDbToColor(defaultExam.slug);

/** All topic slugs for sitemap generation (default exam) */
export const ALL_SLUGS = getExamTopicSlugs(defaultExam.slug);

/** Find topic by slug (default exam) */
export function getTopicBySlug(slug: string) {
  return TOPICS.find((t) => t.slug === slug);
}

/** Find topic by database name (default exam) */
export function getTopicByDbName(dbName: string) {
  return TOPICS.find((t) => t.dbName === dbName);
}
