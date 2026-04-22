# Questionless MVP Design Document

**Date**: 2026-02-05
**Project**: questionless.uk
**Status**: Approved

---

## 1. Overview

Questionless is an AI-powered UK exam preparation platform, starting with Life in the UK Test. The MVP combines scraped seed questions with AI-generated content using Gemini 3 Flash, verified through a full human review process.

**Brand Tagline**: "Question Less, Score More"

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Questionless.uk MVP                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Frontend   │    │   Backend    │    │   External   │      │
│  │  Next.js 14  │───▶│  CF Workers  │───▶│   Services   │      │
│  │  App Router  │    │   D1 + R2    │    │              │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ Cloudflare   │    │     D1       │    │    Clerk     │      │
│  │    Pages     │    │  (SQLite)    │    │    Auth      │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                             │                   │               │
│                      ┌──────┴──────┐           │               │
│                      ▼             ▼           ▼               │
│               ┌──────────┐  ┌──────────┐ ┌──────────┐          │
│               │ Questions│  │  Users   │ │  Stripe  │          │
│               │   R2     │  │ Progress │ │ Payments │          │
│               └──────────┘  └──────────┘ └──────────┘          │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              AI Pipeline (Gemini 3 Flash)                 │  │
│  │  Handbook → Generate → Verify → Review → Question Bank    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Core Components:**
- **Frontend**: Next.js 14 (App Router) + Tailwind CSS + shadcn/ui
- **Backend**: Cloudflare Workers (API Routes)
- **Database**: D1 (user data, progress) + R2 (static question JSON)
- **Auth**: Clerk (primary) + D1 user table backup
- **Payment**: Stripe Checkout + Webhooks
- **AI**: Gemini 3 Flash API (batch generation + verification)

---

## 3. Database Schema (D1)

```sql
-- Users table (Clerk backup + extended data)
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  plan TEXT DEFAULT 'free',
  stripe_customer_id TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Questions table
CREATE TABLE questions (
  id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  chapter TEXT,
  question TEXT NOT NULL,
  options TEXT NOT NULL,
  correct_index INTEGER NOT NULL,
  explanation TEXT,
  handbook_ref TEXT,
  difficulty TEXT DEFAULT 'medium',
  source TEXT NOT NULL,
  verified BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- User answers
CREATE TABLE user_answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  question_id TEXT NOT NULL,
  selected_index INTEGER NOT NULL,
  is_correct BOOLEAN NOT NULL,
  time_spent_ms INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

-- Spaced Repetition records
CREATE TABLE sr_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  question_id TEXT NOT NULL,
  ease_factor REAL DEFAULT 2.5,
  interval_days INTEGER DEFAULT 1,
  repetitions INTEGER DEFAULT 0,
  next_review_at DATETIME,
  UNIQUE(user_id, question_id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Mock exams
CREATE TABLE mock_exams (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  question_ids TEXT NOT NULL,
  answers TEXT,
  score INTEGER,
  total INTEGER DEFAULT 24,
  pass BOOLEAN,
  started_at DATETIME,
  completed_at DATETIME,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Subscriptions
CREATE TABLE subscriptions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan TEXT NOT NULL,
  status TEXT NOT NULL,
  current_period_end DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Indexes
CREATE INDEX idx_questions_topic ON questions(topic);
CREATE INDEX idx_questions_verified ON questions(verified);
CREATE INDEX idx_user_answers_user ON user_answers(user_id);
CREATE INDEX idx_sr_next_review ON sr_records(user_id, next_review_at);
```

---

## 4. Project Structure

```
questionless/
├── src/
│   ├── app/
│   │   ├── (marketing)/
│   │   │   ├── page.tsx
│   │   │   ├── topics/[topic]/page.tsx
│   │   │   ├── pricing/page.tsx
│   │   │   └── about/page.tsx
│   │   ├── (app)/
│   │   │   ├── dashboard/page.tsx
│   │   │   ├── practice/
│   │   │   ├── mock-exam/
│   │   │   ├── review/
│   │   │   ├── progress/page.tsx
│   │   │   └── settings/page.tsx
│   │   ├── api/
│   │   │   ├── questions/
│   │   │   ├── answers/
│   │   │   ├── mock-exam/
│   │   │   ├── sr/
│   │   │   ├── webhooks/stripe/
│   │   │   └── admin/questions/
│   │   └── layout.tsx
│   ├── components/
│   │   ├── ui/
│   │   ├── question/
│   │   ├── exam/
│   │   ├── paywall/
│   │   └── ads/
│   ├── lib/
│   │   ├── db.ts
│   │   ├── auth.ts
│   │   ├── stripe.ts
│   │   ├── sr-algorithm.ts
│   │   └── gemini.ts
│   └── types/
│       └── index.ts
├── scripts/
│   ├── scrape/
│   ├── generate/
│   └── seed/
├── data/
│   ├── scraped/
│   ├── generated/
│   └── verified/
├── wrangler.toml
├── drizzle.config.ts
└── package.json
```

---

## 5. User Flows

### 5.1 Free User Practice Flow

```
Home → Select Topic → Start Practice → Answer → View Explanation → Next
                                         ↓
                                   [Ad every 5 questions]
                                         ↓
                      Complete 30 questions → Results + Paywall prompt
                                         ↓
                              "Unlock Mock Exam & Review"
```

### 5.2 Pro User Mock Exam Flow

```
Dashboard → Start Mock Exam → 24 questions / 45 min timer
                                    ↓
                            Answer (no ads)
                                    ↓
                          Time up / Complete
                                    ↓
                        Results: Score + Pass/Fail
                                    ↓
                      Wrong answers + Add to Review
                                    ↓
                      SR algorithm updates review time
```

### 5.3 Spaced Repetition Review Flow

```
Dashboard shows "Today's review: 12 questions"
                    ↓
            Enter SR review mode
                    ↓
        Correct → ease_factor up → interval extends
        Wrong → ease_factor down → interval resets
                    ↓
            Complete review → Update next_review_at
```

### 5.4 Payment Conversion Flow

```
Free user clicks Pro feature (Mock Exam/Review/SR)
                    ↓
            PaywallModal appears
                    ↓
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
 Monthly £4.99  Annual £29.99  Lifetime £9.99
                    ↓
           Stripe Checkout
                    ↓
        Webhook → Update user.plan
                    ↓
            Unlock Pro features
```

### 5.5 Feature Matrix

| Feature | Free User | Pro User |
|---------|-----------|----------|
| Practice questions | ✅ Unlimited | ✅ Unlimited |
| Ads | ✅ Shown | ❌ Hidden |
| Mock exams | 🔒 Locked | ✅ Unlocked |
| Wrong answer review | 🔒 Locked | ✅ Unlocked |
| SR review | 🔒 Locked | ✅ Unlocked |
| Progress tracking | ✅ Basic | ✅ Detailed |

---

## 6. AI Question Pipeline (Gemini 3 Flash)

### 6.1 Pipeline Architecture

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌────────┐
│ Handbook │ →  │ Generate │ →  │  Auto    │ →  │ Human  │
│ Content  │    │ (Gemini) │    │ Verify   │    │ Review │
└──────────┘    └──────────┘    └──────────┘    └────────┘
     ↓               ↓               ↓              ↓
 Section split   5 questions/batch  Filter errors  Full review → DB
```

### 6.2 Generation Prompt Template

```
You are a Life in the UK Test question generation expert. Generate practice questions based on the following official handbook content.

【Chapter Content】
{chapter_content}

【Requirements】
- Generate 5 multiple choice questions
- Each question has 4 options, only 1 correct answer
- Difficulty distribution: 2 easy, 2 medium, 1 hard
- Must be based on provided content, no fabricated facts
- Provide detailed explanation with original text reference

【Output Format (JSON)】
{
  "questions": [
    {
      "question": "Question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "difficulty": "easy|medium|hard",
      "explanation": "Explanation text",
      "handbook_ref": "Original text quote",
      "confidence": 0.95
    }
  ]
}
```

### 6.3 Auto-Verification Layer

- format_valid: Correct JSON format
- four_options: Exactly 4 options
- single_answer: Single correct answer (0-3)
- has_explanation: Explanation provided
- fact_verified: Second Gemini call to verify facts
- not_duplicate: Similarity check against existing questions

### 6.4 Human Review Process

Full manual review (100%) for Phase 1 to ensure accuracy.

Admin Dashboard → Pending questions list → Review each question
→ ✅ Approve | ✏️ Edit | ❌ Reject
→ Approved → verified = true → Added to question bank

### 6.5 Cost Estimate

| Item | Quantity | Token Estimate | Cost |
|------|----------|----------------|------|
| Generate 500 questions | 100 batches | ~500K tokens | ~$0.50 |
| Fact verification | 500 calls | ~250K tokens | ~$0.25 |
| **MVP Total** | - | ~750K tokens | **~$0.75** |

---

## 7. Data Sources

### 7.1 Scraping Targets

| Source | Content | Purpose | Priority |
|--------|---------|---------|----------|
| gov.uk handbook | Official study guide | AI generation fact source | P0 |
| lifeintheuktests.co.uk | ~400 practice questions | Seed question bank | P0 |

### 7.2 Topics Classification

```typescript
const TOPICS = {
  british_history: "British History",
  modern_britain: "A Modern, Thriving Society",
  uk_government: "The UK Government",
  laws_and_rights: "Laws and Rights",
  geography: "Geography of the UK",
  culture_traditions: "Culture and Traditions",
  everyday_life: "Everyday Life",
  employment: "Employment",
  citizenship: "Becoming a Citizen"
} as const;
```

---

## 8. Technical Decisions

| Area | Choice | Rationale |
|------|--------|-----------|
| Frontend | Next.js 14 App Router | SEO, performance, Cloudflare native |
| Hosting | Cloudflare Pages + Workers | Cost-effective, edge performance |
| Database | D1 (SQLite) | Simple, free tier generous |
| Storage | R2 | Static question JSON storage |
| Auth | Clerk + D1 backup | Fast setup, data portability |
| Payment | Stripe | Industry standard |
| UI | shadcn/ui + Tailwind | Modern, customizable |
| ORM | Drizzle | Lightweight, D1 native |
| AI | Gemini 3 Flash | Cost-effective, fast |
| Ads | Google AdSense | Web monetization |

---

## 9. Pricing Structure

| Plan | Price | Features |
|------|-------|----------|
| Free | £0 | Unlimited practice, ads shown, 30 questions before paywall prompt |
| Pro Monthly | £4.99/month | No ads, mock exams, review, SR |
| Pro Annual | £29.99/year | Same as monthly |
| Lifetime | £9.99 one-time | Same as Pro, forever |

---

## 10. SEO Strategy

**Page Structure**: Topic-based landing pages (~20 pages)

**Target Keywords**:
- Primary: "life in the uk test"
- Long-tail: "life in uk test [topic] questions"
- Local: "life in uk test practice free"

Each topic page includes:
- Topic overview with key facts
- Free practice questions (embedded)
- CTA to full practice mode

---

## 11. Success Metrics

**Product Metrics:**
- DAU/MAU ratio: >20%
- 7-day retention: >40%
- Completion rate (first mock exam): >60%
- Average questions per user: >100/month

**Business Metrics:**
- Free → Pro conversion: >5%
- Ad RPM: >£4
- LTV/CAC: >3:1
- Monthly churn: <8%

---

## 12. Phase 1 Scope (4-6 weeks)

**In Scope:**
- ✅ Life in the UK Test complete question bank (300-500 questions)
- ✅ Web version (Next.js + Cloudflare)
- ✅ Basic Freemium model
- ✅ Stripe payment integration
- ✅ User auth (Clerk)
- ✅ Mock exam mode
- ✅ Wrong answer review
- ✅ Spaced Repetition
- ✅ Topic-based SEO pages
- ✅ Ad integration

**Out of Scope (Phase 2+):**
- ❌ iOS/Android apps
- ❌ DVSA Theory Test
- ❌ Real-time AI generation (Pro+)
- ❌ Offline mode
- ❌ B2B licensing
- ❌ Multi-language support

---

*Document approved: 2026-02-05*
