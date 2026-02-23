// Topic definitions
export const TOPICS = {
  british_history: 'British History',
  modern_britain: 'A Modern, Thriving Society',
  uk_government: 'The UK Government',
  laws_and_rights: 'Laws and Rights',
  geography: 'Geography of the UK',
  culture_traditions: 'Culture and Traditions',
  everyday_life: 'Everyday Life',
  employment: 'Employment',
  citizenship: 'Becoming a Citizen',
  sports: 'Sports',
} as const;

export type TopicKey = keyof typeof TOPICS;

// Question types
export interface QuestionOption {
  text: string;
  isCorrect: boolean;
}

export interface Question {
  id: string;
  topic: TopicKey;
  chapter?: string;
  question: string;
  options: string[];
  correctIndex: number;
  explanation?: string;
  handbookRef?: string;
  difficulty: 'easy' | 'medium' | 'hard';
  source: 'scraped' | 'ai_generated' | 'manual';
  verified: boolean;
}

// User progress
export interface UserProgress {
  totalQuestions: number;
  correctAnswers: number;
  incorrectAnswers: number;
  accuracy: number;
  topicProgress: Record<TopicKey, {
    total: number;
    correct: number;
  }>;
}

// Mock exam
export interface MockExamResult {
  id: string;
  score: number;
  total: number;
  pass: boolean;
  timeSpent: number;
  questions: {
    questionId: string;
    selectedIndex: number;
    isCorrect: boolean;
  }[];
}

// Spaced Repetition
export interface SRState {
  easeFactor: number;
  intervalDays: number;
  repetitions: number;
  nextReviewAt: Date;
}

// Plan types
export type PlanType = 'free' | 'pro' | 'pro_plus';

export interface PlanFeatures {
  unlimitedPractice: boolean;
  mockExams: boolean;
  wrongAnswerReview: boolean;
  spacedRepetition: boolean;
  noAds: boolean;
  detailedProgress: boolean;
}

export const PLAN_FEATURES: Record<PlanType, PlanFeatures> = {
  free: {
    unlimitedPractice: true,
    mockExams: false,
    wrongAnswerReview: false,
    spacedRepetition: false,
    noAds: false,
    detailedProgress: false,
  },
  pro: {
    unlimitedPractice: true,
    mockExams: true,
    wrongAnswerReview: true,
    spacedRepetition: true,
    noAds: true,
    detailedProgress: true,
  },
  pro_plus: {
    unlimitedPractice: true,
    mockExams: true,
    wrongAnswerReview: true,
    spacedRepetition: true,
    noAds: true,
    detailedProgress: true,
  },
};

// Pricing
export const PRICING = {
  pro_monthly: {
    price: 4.99,
    currency: 'GBP',
    interval: 'month',
    stripePriceId: process.env.STRIPE_PRO_MONTHLY_PRICE_ID || 'price_1SxbXCA2CdsoSr4EnOP3y8GE',
  },
  pro_annual: {
    price: 29.99,
    currency: 'GBP',
    interval: 'year',
    stripePriceId: process.env.STRIPE_PRO_ANNUAL_PRICE_ID || 'price_1SxbXEA2CdsoSr4E0Gi0NaAS',
  },
  lifetime: {
    price: 9.99,
    currency: 'GBP',
    interval: 'once',
    stripePriceId: process.env.STRIPE_LIFETIME_PRICE_ID || 'price_1SxbXGA2CdsoSr4EAfgCWRSb',
  },
};
