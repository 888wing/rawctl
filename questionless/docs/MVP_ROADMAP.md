# Questionless MVP Roadmap

## Current State Analysis

### ✅ Completed
- UI/UX Design System (Claymorphism, 9.2/10 score)
- All frontend pages (home, practice, dashboard, mock-exam, review, progress)
- QuestionCard component with keyboard support & animations
- Session persistence with localStorage
- Database schema (Drizzle ORM)
- 26 seed questions in migrations
- Gemini AI question generation API
- Clerk authentication setup

### ❌ Gap: Static Data vs D1 Database
**Problem**: Practice pages use hardcoded `sampleQuestions` object, NOT connected to D1.

```tsx
// Current (static)
const sampleQuestions: Record<string, QuestionData[]> = { ... }

// Needed (D1)
const questions = await db.select().from(questionsTable).where(...)
```

---

## MVP Feature Requirements

### Core MVP (Must Have)
1. **D1 Database Integration** - Fetch real questions from database
2. **Question Bank** - 200+ verified questions covering all 9 topics
3. **User Progress Tracking** - Save answers to database
4. **Mock Exam Mode** - Timed 24 questions in 45 minutes
5. **Basic Analytics** - Score history, topic accuracy

### Nice to Have (Post-MVP)
- Spaced repetition algorithm
- AI-generated personalized questions
- Stripe payments for Pro plan
- Leaderboards

---

## Phase 1: D1 Integration (P0)

### 1.1 Database Setup
```bash
# Apply migrations to local D1
npm run db:migrate
```

### 1.2 API Routes (Create)

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/questions` | GET | List questions (with filters) |
| `/api/questions/[id]` | GET | Single question |
| `/api/questions/topic/[slug]` | GET | Questions by topic |
| `/api/questions/random` | GET | Random 10 questions |
| `/api/user/answers` | POST | Save user answer |
| `/api/user/stats` | GET | Get user statistics |
| `/api/mock-exam` | POST | Create mock exam session |
| `/api/mock-exam/[id]` | GET/PUT | Get/Update exam |

### 1.3 Update Practice Page
- Replace static `sampleQuestions` with API fetch
- Add loading states for database queries
- Handle error states gracefully

---

## Phase 2: Question Bank Expansion (P1)

### 2.1 Topic Coverage Target

| Topic | Current | Target | Priority |
|-------|---------|--------|----------|
| The Tudors | 5 | 20 | High |
| The Stuarts | 5 | 20 | High |
| English Civil War | 5 | 15 | High |
| Science & Innovation | 4 | 15 | Medium |
| Sports | 5 | 15 | Medium |
| UK Government | 0 | 25 | Critical |
| Laws & Rights | 0 | 20 | Critical |
| Geography | 0 | 15 | Medium |
| Culture & Traditions | 0 | 20 | Medium |
| Modern Britain | 0 | 15 | Medium |
| Values & Principles | 0 | 15 | Medium |
| Everyday Life | 0 | 15 | Medium |
| **Total** | **26** | **210** | - |

### 2.2 Question Generation Strategy
1. Use existing Gemini API to batch generate
2. Manual verification before adding to DB
3. Tag questions with handbook chapter reference

---

## Phase 3: User Progress System (P1)

### 3.1 Data Flow
```
User answers question
  → POST /api/user/answers (save to userAnswers table)
  → Update user statistics
  → Return updated progress

Dashboard loads
  → GET /api/user/stats
  → Display accuracy, streak, topic progress
```

### 3.2 Progress Metrics
- Total questions answered
- Overall accuracy %
- Per-topic accuracy %
- Study streak (days)
- Mock exam pass rate

---

## Phase 4: Mock Exam Mode (P2)

### 4.1 Exam Flow
1. User clicks "Start Mock Exam"
2. Create exam session in database
3. Fetch 24 random questions
4. Start 45-minute timer
5. Save answers as user progresses
6. Auto-submit when timer expires
7. Show results with pass/fail

### 4.2 Database Updates
- Use existing `mockExams` table
- Store question IDs, answers, score, timing

---

## Implementation Order

```
Week 1: Database Foundation
├── Day 1-2: D1 setup + API routes for questions
├── Day 3-4: Connect practice page to D1
└── Day 5: Testing + bug fixes

Week 2: Question Expansion
├── Day 1-3: Generate questions for missing topics
├── Day 4-5: Verify and seed to database
└── Day 6-7: Test all topics

Week 3: User Progress
├── Day 1-2: Answer saving API
├── Day 3-4: Dashboard stats from D1
└── Day 5: Progress page from D1

Week 4: Mock Exam
├── Day 1-2: Exam creation/management
├── Day 3-4: Timer + auto-submit
└── Day 5-7: Polish + testing
```

---

## Files to Create/Modify

### New API Routes
```
src/app/api/
├── questions/
│   ├── route.ts           # GET all questions
│   ├── [id]/route.ts      # GET single question
│   ├── topic/[slug]/route.ts  # GET by topic
│   └── random/route.ts    # GET random questions
├── user/
│   ├── answers/route.ts   # POST save answer
│   └── stats/route.ts     # GET user stats
└── mock-exam/
    ├── route.ts           # POST create exam
    └── [id]/route.ts      # GET/PUT exam
```

### Files to Update
```
src/app/practice/[topic]/page.tsx  # Use D1 instead of static
src/app/dashboard/page.tsx         # Fetch real stats from D1
src/app/progress/page.tsx          # Fetch real progress from D1
src/app/review/page.tsx            # Fetch due reviews from D1
src/app/mock-exam/start/page.tsx   # New - actual exam page
```

### New Library Files
```
src/lib/db/index.ts        # D1 connection helper
src/lib/db/queries.ts      # Common database queries
```

---

## Quick Start Command

To begin Phase 1 implementation:

```bash
# 1. Verify D1 is set up
wrangler d1 list

# 2. Apply migrations
npm run db:migrate

# 3. Verify questions exist
wrangler d1 execute questionless-db --local --command="SELECT COUNT(*) FROM questions"

# 4. Start development
npm run dev
```

---

## Success Criteria for MVP

- [ ] 200+ questions in database
- [ ] All 9 topics have at least 15 questions
- [ ] Practice mode fetches from D1
- [ ] User answers saved to database
- [ ] Dashboard shows real statistics
- [ ] Mock exam with 45-minute timer works
- [ ] Pass rate shown correctly (75% threshold)
