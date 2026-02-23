# Questionless - Task Tracker

> Last updated: 2026-02-05 | Branch: `main` (v1.4 merged)

---

## Current Status Summary

| Area | Status | Detail |
|------|--------|--------|
| Core UI Pages | ✅ Done | 10+ pages built with Claymorphism design |
| API Endpoints | ✅ Done | 9 API routes, D1 connected |
| DB Schema | ✅ Done | 6 tables, migrations applied |
| Question Bank | ✅ Done | 224 verified questions seeded |
| Auth (Clerk) | ✅ Done | Sign-in/up + middleware + plan checks |
| SR Algorithm | ✅ Done | SM-2 implementation + DB wiring |
| DB Migrations | ✅ Done | Generated & applied to local D1 |
| Stripe Payments | ✅ Done | Pricing page, checkout API, webhook, success/cancel |
| Real DB Queries | ✅ Done | All pages query D1 (dashboard, progress, review) |
| Spaced Repetition | ✅ Done | APIs, review session, practice integration |
| Merge to main | ✅ Done | v1.4 merged, branch deleted |
| Deployment | ❌ Not deployed | Requires Cloudflare setup |

---

## Completed Phases

### Phase 1: Data Layer ✅
- [x] DB migrations generated & applied (6 tables)
- [x] 224 questions seeded with `verified = true`
- [x] Dashboard, Progress, Review pages connected to real D1 queries
- [x] `isPro()` and `getUserPlan()` query subscriptions/users tables

### Phase 2: Payments (Stripe) ✅
- [x] Pricing page with plan comparison (`/pricing`)
- [x] Stripe Checkout API (monthly, annual, lifetime)
- [x] Stripe Webhook (checkout.session.completed, subscription lifecycle)
- [x] Success/Cancel pages (`/pricing/success`, `/pricing/cancel`)

### Phase 3: Spaced Repetition ✅
- [x] POST `/api/user/review` - update SR records after answer
- [x] GET `/api/user/review/due` - get questions due for review
- [x] Review session page (`/review/session`)
- [x] Practice flow calls SR update endpoint alongside answer tracking

---

## Remaining Phases

### Phase 4: Question Bank Expansion
Requires `GOOGLE_AI_API_KEY` for Gemini API.

- [ ] Map all Life in the UK handbook chapters against existing 224 questions
- [ ] Identify under-covered topics (use scraped data in `data/scraped/`)
- [ ] Use Gemini API to generate questions for weak topics (target: 500+)
- [ ] Review and verify generated questions

### Phase 5: Deployment
Requires Cloudflare account + environment variables configured.

- [ ] Create D1 database in Cloudflare dashboard
- [ ] Apply migrations to remote D1: `wrangler d1 migrations apply questionless-db --remote`
- [ ] Seed questions to remote D1
- [ ] Set environment variables in Cloudflare Pages:
  - `CLERK_SECRET_KEY`, `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
  - `GOOGLE_AI_API_KEY`
  - `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
  - `NEXT_PUBLIC_APP_URL`
- [ ] Run `npm run pages:deploy`
- [ ] Verify all pages load correctly
- [ ] Test auth flow end-to-end
- [ ] Set up Stripe webhook URL pointing to deployed app

### Phase 6: Polish
- [ ] Test full user journey: sign up -> practice -> mock exam -> review -> progress
- [ ] Test payment flow with Stripe test mode
- [ ] Mobile responsiveness check on all pages
- [ ] Accessibility audit (keyboard nav, screen reader)
- [ ] Configure ESLint
