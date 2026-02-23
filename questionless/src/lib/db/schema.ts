import { sql } from 'drizzle-orm';
import { sqliteTable, text, integer, real } from 'drizzle-orm/sqlite-core';

// Users table (Clerk backup + extended data)
export const users = sqliteTable('users', {
  id: text('id').primaryKey(), // Clerk user ID
  email: text('email').notNull().unique(),
  name: text('name'),
  plan: text('plan').default('free'), // free | pro | pro_plus
  stripeCustomerId: text('stripe_customer_id'),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text('updated_at').default(sql`CURRENT_TIMESTAMP`),
});

// Questions table
export const questions = sqliteTable('questions', {
  id: text('id').primaryKey(),
  exam: text('exam').notNull().default('life-in-uk'),
  topic: text('topic').notNull(),
  chapter: text('chapter'),
  question: text('question').notNull(),
  options: text('options').notNull(), // JSON array
  correctIndex: integer('correct_index').notNull(),
  explanation: text('explanation'),
  handbookRef: text('handbook_ref'),
  difficulty: text('difficulty').default('medium'), // easy | medium | hard
  source: text('source').notNull(), // scraped | ai_generated | manual
  verified: integer('verified', { mode: 'boolean' }).default(false),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
});

// User answers
export const userAnswers = sqliteTable('user_answers', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  userId: text('user_id').notNull().references(() => users.id),
  questionId: text('question_id').notNull().references(() => questions.id),
  selectedIndex: integer('selected_index').notNull(),
  isCorrect: integer('is_correct', { mode: 'boolean' }).notNull(),
  timeSpentMs: integer('time_spent_ms'),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
});

// Spaced Repetition records
export const srRecords = sqliteTable('sr_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  userId: text('user_id').notNull().references(() => users.id),
  questionId: text('question_id').notNull().references(() => questions.id),
  easeFactor: real('ease_factor').default(2.5),
  intervalDays: integer('interval_days').default(1),
  repetitions: integer('repetitions').default(0),
  nextReviewAt: text('next_review_at'),
});

// Mock exams
export const mockExams = sqliteTable('mock_exams', {
  id: text('id').primaryKey(),
  userId: text('user_id').notNull().references(() => users.id),
  exam: text('exam').notNull().default('life-in-uk'),
  questionIds: text('question_ids').notNull(), // JSON array
  answers: text('answers'), // JSON object
  score: integer('score'),
  total: integer('total').default(24),
  passed: integer('passed', { mode: 'boolean' }),
  startedAt: text('started_at'),
  completedAt: text('completed_at'),
});

// Subscriptions
export const subscriptions = sqliteTable('subscriptions', {
  id: text('id').primaryKey(), // Stripe subscription ID
  userId: text('user_id').notNull().references(() => users.id),
  plan: text('plan').notNull(),
  status: text('status').notNull(), // active | canceled | past_due
  currentPeriodEnd: text('current_period_end'),
  createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`),
});

// Types
export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type Question = typeof questions.$inferSelect;
export type NewQuestion = typeof questions.$inferInsert;
export type UserAnswer = typeof userAnswers.$inferSelect;
export type SRRecord = typeof srRecords.$inferSelect;
export type MockExam = typeof mockExams.$inferSelect;
export type Subscription = typeof subscriptions.$inferSelect;
