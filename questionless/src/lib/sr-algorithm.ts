/**
 * SM-2 Spaced Repetition Algorithm
 * Based on SuperMemo 2 algorithm
 */

export interface SRState {
  easeFactor: number;
  intervalDays: number;
  repetitions: number;
  nextReviewAt: Date;
}

export interface SRUpdate {
  quality: number; // 0-5, where 0 = complete failure, 5 = perfect recall
}

const MIN_EASE_FACTOR = 1.3;
const DEFAULT_EASE_FACTOR = 2.5;

/**
 * Calculate the next review state based on answer quality
 * @param currentState Current SR state
 * @param quality Answer quality (0-5)
 * @returns Updated SR state
 */
export function calculateNextReview(
  currentState: SRState | null,
  quality: number
): SRState {
  // Initialize state if null
  if (!currentState) {
    currentState = {
      easeFactor: DEFAULT_EASE_FACTOR,
      intervalDays: 1,
      repetitions: 0,
      nextReviewAt: new Date(),
    };
  }

  // Clamp quality to 0-5
  quality = Math.max(0, Math.min(5, quality));

  let { easeFactor, intervalDays, repetitions } = currentState;

  // If quality < 3, reset repetitions (failed recall)
  if (quality < 3) {
    repetitions = 0;
    intervalDays = 1;
  } else {
    // Successful recall
    if (repetitions === 0) {
      intervalDays = 1;
    } else if (repetitions === 1) {
      intervalDays = 6;
    } else {
      intervalDays = Math.round(intervalDays * easeFactor);
    }
    repetitions += 1;
  }

  // Update ease factor
  // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
  easeFactor =
    easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  easeFactor = Math.max(MIN_EASE_FACTOR, easeFactor);

  // Calculate next review date
  const nextReviewAt = new Date();
  nextReviewAt.setDate(nextReviewAt.getDate() + intervalDays);

  return {
    easeFactor,
    intervalDays,
    repetitions,
    nextReviewAt,
  };
}

/**
 * Convert boolean answer (correct/incorrect) to quality score
 * @param isCorrect Whether the answer was correct
 * @param timeSpentMs Time spent on the question in milliseconds
 * @returns Quality score (0-5)
 */
export function answerToQuality(isCorrect: boolean, timeSpentMs?: number): number {
  if (!isCorrect) {
    return 1; // Incorrect answer
  }

  // Correct answer - adjust based on time spent
  if (!timeSpentMs) {
    return 4; // Default for correct answer
  }

  // Quick answer (< 10s) = perfect recall
  if (timeSpentMs < 10000) {
    return 5;
  }
  // Medium time (10-30s) = good recall
  if (timeSpentMs < 30000) {
    return 4;
  }
  // Slow answer (> 30s) = hesitant recall
  return 3;
}

/**
 * Get questions due for review
 * @param records All SR records for a user
 * @returns Question IDs that are due for review
 */
export function getDueQuestions(
  records: Array<{ questionId: string; nextReviewAt: string | null }>
): string[] {
  const now = new Date();
  return records
    .filter((record) => {
      if (!record.nextReviewAt) return true;
      return new Date(record.nextReviewAt) <= now;
    })
    .map((record) => record.questionId);
}
