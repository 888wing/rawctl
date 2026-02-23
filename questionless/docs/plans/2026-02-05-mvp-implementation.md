# Questionless MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete MVP by implementing Stripe payments, pricing page, feature gating, ad integration, and seeding question bank to D1.

**Current State:**
- ✅ D1 database schema complete
- ✅ API routes for questions, answers, stats, mock-exam
- ✅ Practice pages, dashboard, mock exam UI
- ✅ Clerk authentication
- ✅ 200 questions generated in JSON
- ❌ No Stripe checkout/webhooks
- ❌ No pricing page
- ❌ No feature gating
- ❌ No ad integration
- ❌ Questions not seeded to D1

**Tech Stack:** Next.js 15 (App Router), Cloudflare D1, Drizzle ORM, Clerk Auth, Stripe, TypeScript

---

## Phase 1: Seed Question Bank to D1

### Task 1.1: Create Question Seeding Script

**Files:**
- Create: `scripts/seed-questions.ts`

**Step 1: Create the seeding script**

```typescript
// scripts/seed-questions.ts
import { drizzle } from 'drizzle-orm/d1';
import * as schema from '../src/lib/db/schema';
import fs from 'fs';
import path from 'path';

// This script is run via wrangler d1 execute or tsx
async function seedQuestions() {
  // Read generated questions
  const questionsPath = path.join(process.cwd(), 'data/generated-questions.json');
  const rawData = fs.readFileSync(questionsPath, 'utf-8');
  const questions = JSON.parse(rawData);

  console.log(`Found ${questions.length} questions to seed`);

  // Generate SQL INSERT statements
  const inserts = questions.map((q: any, index: number) => {
    const id = `q-${String(index + 1).padStart(4, '0')}`;
    const topic = q.topic;
    const question = q.question.replace(/'/g, "''");
    const options = JSON.stringify(q.options).replace(/'/g, "''");
    const correctIndex = q.correct_index;
    const explanation = (q.explanation || '').replace(/'/g, "''");
    const handbookRef = (q.handbook_ref || '').replace(/'/g, "''");
    const difficulty = q.difficulty || 'medium';
    const source = 'ai_generated';

    return `INSERT OR REPLACE INTO questions (id, topic, question, options, correct_index, explanation, handbook_ref, difficulty, source, verified) VALUES ('${id}', '${topic}', '${question}', '${options}', ${correctIndex}, '${explanation}', '${handbookRef}', '${difficulty}', '${source}', 1);`;
  });

  // Write to SQL file for execution
  const sqlPath = path.join(process.cwd(), 'scripts/seed-questions.sql');
  fs.writeFileSync(sqlPath, inserts.join('\n'));

  console.log(`Generated ${inserts.length} INSERT statements`);
  console.log(`SQL file written to: ${sqlPath}`);
  console.log('\nRun: wrangler d1 execute questionless-db --local --file=scripts/seed-questions.sql');
}

seedQuestions().catch(console.error);
```

**Step 2: Run the seeding script**

```bash
npx tsx scripts/seed-questions.ts
wrangler d1 execute questionless-db --local --file=scripts/seed-questions.sql
```

**Step 3: Verify questions in D1**

```bash
wrangler d1 execute questionless-db --local --command="SELECT COUNT(*) FROM questions"
```

Expected: 200 questions

**Step 4: Commit**

```bash
git add scripts/seed-questions.ts scripts/seed-questions.sql
git commit -m "feat(db): add question seeding script and seed 200 questions"
```

---

## Phase 2: Stripe Payment Integration

### Task 2.1: Create Stripe Configuration

**Files:**
- Create: `src/lib/stripe.ts`

**Step 1: Create Stripe utilities**

```typescript
// src/lib/stripe.ts
import Stripe from 'stripe';

// Server-side Stripe instance
export function getStripe() {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    throw new Error('STRIPE_SECRET_KEY is not set');
  }
  return new Stripe(secretKey, {
    apiVersion: '2023-10-16',
  });
}

// Price IDs - update these with actual Stripe price IDs
export const STRIPE_PRICES = {
  pro_monthly: process.env.STRIPE_PRICE_PRO_MONTHLY || 'price_pro_monthly',
  pro_annual: process.env.STRIPE_PRICE_PRO_ANNUAL || 'price_pro_annual',
  lifetime: process.env.STRIPE_PRICE_LIFETIME || 'price_lifetime',
} as const;

export type PriceKey = keyof typeof STRIPE_PRICES;

// Map price IDs to plan types
export const PRICE_TO_PLAN: Record<string, string> = {
  [STRIPE_PRICES.pro_monthly]: 'pro',
  [STRIPE_PRICES.pro_annual]: 'pro',
  [STRIPE_PRICES.lifetime]: 'pro',
};
```

**Step 2: Commit**

```bash
git add src/lib/stripe.ts
git commit -m "feat(stripe): add Stripe configuration utilities"
```

---

### Task 2.2: Create Checkout API Route

**Files:**
- Create: `src/app/api/stripe/checkout/route.ts`

**Step 1: Create checkout endpoint**

```typescript
// src/app/api/stripe/checkout/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth, currentUser } from '@clerk/nextjs/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { users } from '@/lib/db/schema';
import { eq } from 'drizzle-orm';
import { getStripe, STRIPE_PRICES, type PriceKey } from '@/lib/stripe';

export const runtime = 'edge';

export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth();
    const user = await currentUser();

    if (!userId || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { priceKey } = body as { priceKey: PriceKey };

    if (!priceKey || !STRIPE_PRICES[priceKey]) {
      return NextResponse.json({ error: 'Invalid price' }, { status: 400 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);
    const stripe = getStripe();

    // Get or create Stripe customer
    let [dbUser] = await db
      .select()
      .from(users)
      .where(eq(users.id, userId));

    let customerId = dbUser?.stripeCustomerId;

    if (!customerId) {
      // Create Stripe customer
      const customer = await stripe.customers.create({
        email: user.emailAddresses[0]?.emailAddress,
        name: user.firstName ? `${user.firstName} ${user.lastName || ''}`.trim() : undefined,
        metadata: {
          clerkUserId: userId,
        },
      });
      customerId = customer.id;

      // Save customer ID to database
      if (dbUser) {
        await db
          .update(users)
          .set({ stripeCustomerId: customerId })
          .where(eq(users.id, userId));
      } else {
        await db.insert(users).values({
          id: userId,
          email: user.emailAddresses[0]?.emailAddress || '',
          name: user.firstName || null,
          stripeCustomerId: customerId,
        });
      }
    }

    // Determine checkout mode
    const isOneTime = priceKey === 'lifetime';
    const priceId = STRIPE_PRICES[priceKey];

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: isOneTime ? 'payment' : 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: `${request.headers.get('origin')}/dashboard?checkout=success`,
      cancel_url: `${request.headers.get('origin')}/pricing?checkout=canceled`,
      metadata: {
        clerkUserId: userId,
        priceKey,
      },
    });

    return NextResponse.json({ url: session.url });
  } catch (error) {
    console.error('Checkout error:', error);
    return NextResponse.json(
      { error: 'Failed to create checkout session' },
      { status: 500 }
    );
  }
}
```

**Step 2: Commit**

```bash
git add src/app/api/stripe/checkout/route.ts
git commit -m "feat(api): add POST /api/stripe/checkout endpoint"
```

---

### Task 2.3: Create Stripe Webhook Handler

**Files:**
- Create: `src/app/api/stripe/webhook/route.ts`

**Step 1: Create webhook endpoint**

```typescript
// src/app/api/stripe/webhook/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { users, subscriptions } from '@/lib/db/schema';
import { eq } from 'drizzle-orm';
import { getStripe, PRICE_TO_PLAN } from '@/lib/stripe';
import Stripe from 'stripe';

export const runtime = 'edge';

export async function POST(request: NextRequest) {
  const body = await request.text();
  const signature = request.headers.get('stripe-signature');

  if (!signature) {
    return NextResponse.json({ error: 'Missing signature' }, { status: 400 });
  }

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    console.error('STRIPE_WEBHOOK_SECRET not set');
    return NextResponse.json({ error: 'Server error' }, { status: 500 });
  }

  let event: Stripe.Event;
  const stripe = getStripe();

  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  const { env } = getRequestContext();
  const db = getDb(env.DB);

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        const clerkUserId = session.metadata?.clerkUserId;

        if (!clerkUserId) {
          console.error('No clerkUserId in session metadata');
          break;
        }

        // Determine plan from price
        const priceKey = session.metadata?.priceKey;
        const plan = priceKey === 'lifetime' ? 'pro' : 'pro';

        // Update user plan
        await db
          .update(users)
          .set({ plan })
          .where(eq(users.id, clerkUserId));

        // If subscription, create subscription record
        if (session.subscription) {
          const subscription = await stripe.subscriptions.retrieve(
            session.subscription as string
          );

          await db.insert(subscriptions).values({
            id: subscription.id,
            userId: clerkUserId,
            plan,
            status: subscription.status,
            currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
          }).onConflictDoUpdate({
            target: subscriptions.id,
            set: {
              status: subscription.status,
              currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
            },
          });
        }

        console.log(`User ${clerkUserId} upgraded to ${plan}`);
        break;
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription;

        await db
          .update(subscriptions)
          .set({
            status: subscription.status,
            currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
          })
          .where(eq(subscriptions.id, subscription.id));
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;

        // Update subscription status
        await db
          .update(subscriptions)
          .set({ status: 'canceled' })
          .where(eq(subscriptions.id, subscription.id));

        // Get user and downgrade to free
        const [sub] = await db
          .select()
          .from(subscriptions)
          .where(eq(subscriptions.id, subscription.id));

        if (sub) {
          await db
            .update(users)
            .set({ plan: 'free' })
            .where(eq(users.id, sub.userId));
        }
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('Webhook processing error:', error);
    return NextResponse.json({ error: 'Webhook processing failed' }, { status: 500 });
  }
}
```

**Step 2: Commit**

```bash
git add src/app/api/stripe/webhook/route.ts
git commit -m "feat(api): add Stripe webhook handler"
```

---

### Task 2.4: Create Customer Portal API

**Files:**
- Create: `src/app/api/stripe/portal/route.ts`

**Step 1: Create portal endpoint**

```typescript
// src/app/api/stripe/portal/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@clerk/nextjs/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { users } from '@/lib/db/schema';
import { eq } from 'drizzle-orm';
import { getStripe } from '@/lib/stripe';

export const runtime = 'edge';

export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);
    const stripe = getStripe();

    const [user] = await db
      .select()
      .from(users)
      .where(eq(users.id, userId));

    if (!user?.stripeCustomerId) {
      return NextResponse.json(
        { error: 'No subscription found' },
        { status: 400 }
      );
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: user.stripeCustomerId,
      return_url: `${request.headers.get('origin')}/dashboard`,
    });

    return NextResponse.json({ url: session.url });
  } catch (error) {
    console.error('Portal error:', error);
    return NextResponse.json(
      { error: 'Failed to create portal session' },
      { status: 500 }
    );
  }
}
```

**Step 2: Commit**

```bash
git add src/app/api/stripe/portal/route.ts
git commit -m "feat(api): add Stripe customer portal endpoint"
```

---

## Phase 3: Pricing Page

### Task 3.1: Create Pricing Page

**Files:**
- Create: `src/app/pricing/page.tsx`

**Step 1: Create the pricing page**

```typescript
// src/app/pricing/page.tsx
import { auth } from '@clerk/nextjs/server';
import { PricingCards } from './PricingCards';

export const metadata = {
  title: 'Pricing - Questionless',
  description: 'Choose the plan that works for you. Start free, upgrade when ready.',
};

export default async function PricingPage() {
  const { userId } = await auth();

  return (
    <div className="min-h-screen bg-gradient-hero py-12 px-4">
      <div className="max-w-5xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl sm:text-5xl font-nunito font-bold text-slate-800 mb-4">
            Simple, Transparent Pricing
          </h1>
          <p className="text-lg text-slate-600 max-w-2xl mx-auto">
            Start practicing for free. Upgrade to unlock mock exams, spaced repetition, and an ad-free experience.
          </p>
        </div>

        {/* Pricing Cards */}
        <PricingCards isAuthenticated={!!userId} />

        {/* FAQ Section */}
        <div className="mt-16">
          <h2 className="text-2xl font-nunito font-bold text-center text-slate-800 mb-8">
            Frequently Asked Questions
          </h2>
          <div className="grid md:grid-cols-2 gap-6">
            <div className="card-clay-static p-6">
              <h3 className="font-semibold text-slate-800 mb-2">Can I cancel anytime?</h3>
              <p className="text-slate-600 text-sm">
                Yes! You can cancel your subscription at any time. You'll continue to have access until the end of your billing period.
              </p>
            </div>
            <div className="card-clay-static p-6">
              <h3 className="font-semibold text-slate-800 mb-2">What's included in the Lifetime plan?</h3>
              <p className="text-slate-600 text-sm">
                The Lifetime plan gives you all Pro features forever with a single payment. No recurring charges.
              </p>
            </div>
            <div className="card-clay-static p-6">
              <h3 className="font-semibold text-slate-800 mb-2">Do I need Pro to practice?</h3>
              <p className="text-slate-600 text-sm">
                No! You can practice unlimited questions for free. Pro unlocks mock exams, spaced repetition, and removes ads.
              </p>
            </div>
            <div className="card-clay-static p-6">
              <h3 className="font-semibold text-slate-800 mb-2">Is my payment secure?</h3>
              <p className="text-slate-600 text-sm">
                Yes, all payments are processed securely through Stripe. We never store your card details.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
```

**Step 2: Create PricingCards component**

```typescript
// src/app/pricing/PricingCards.tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, X, Loader2 } from 'lucide-react';

interface PricingCardsProps {
  isAuthenticated: boolean;
}

const plans = [
  {
    name: 'Free',
    price: '£0',
    period: 'forever',
    description: 'Perfect for getting started',
    features: [
      { name: 'Unlimited practice questions', included: true },
      { name: 'All 10 topics', included: true },
      { name: 'Basic progress tracking', included: true },
      { name: 'Mock exams', included: false },
      { name: 'Spaced repetition review', included: false },
      { name: 'Ad-free experience', included: false },
    ],
    priceKey: null,
    popular: false,
  },
  {
    name: 'Pro Monthly',
    price: '£4.99',
    period: '/month',
    description: 'Full access, cancel anytime',
    features: [
      { name: 'Unlimited practice questions', included: true },
      { name: 'All 10 topics', included: true },
      { name: 'Detailed progress analytics', included: true },
      { name: 'Unlimited mock exams', included: true },
      { name: 'Spaced repetition review', included: true },
      { name: 'Ad-free experience', included: true },
    ],
    priceKey: 'pro_monthly',
    popular: true,
  },
  {
    name: 'Lifetime',
    price: '£9.99',
    period: 'one-time',
    description: 'Best value, pay once',
    features: [
      { name: 'Unlimited practice questions', included: true },
      { name: 'All 10 topics', included: true },
      { name: 'Detailed progress analytics', included: true },
      { name: 'Unlimited mock exams', included: true },
      { name: 'Spaced repetition review', included: true },
      { name: 'Ad-free experience', included: true },
    ],
    priceKey: 'lifetime',
    popular: false,
    badge: 'Best Value',
  },
];

export function PricingCards({ isAuthenticated }: PricingCardsProps) {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);

  const handleSelectPlan = async (priceKey: string | null) => {
    if (!priceKey) {
      // Free plan - just go to sign up or dashboard
      router.push(isAuthenticated ? '/dashboard' : '/sign-up');
      return;
    }

    if (!isAuthenticated) {
      router.push('/sign-up');
      return;
    }

    setLoading(priceKey);

    try {
      const res = await fetch('/api/stripe/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceKey }),
      });

      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      } else {
        throw new Error(data.error || 'Failed to create checkout');
      }
    } catch (error) {
      console.error('Checkout error:', error);
      alert('Failed to start checkout. Please try again.');
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="grid md:grid-cols-3 gap-6">
      {plans.map((plan) => (
        <div
          key={plan.name}
          className={`card-clay p-6 relative ${
            plan.popular ? 'ring-2 ring-primary' : ''
          }`}
        >
          {plan.popular && (
            <div className="absolute -top-3 left-1/2 -translate-x-1/2">
              <span className="bg-gradient-primary text-white text-xs font-semibold px-3 py-1 rounded-full">
                Most Popular
              </span>
            </div>
          )}
          {plan.badge && (
            <div className="absolute -top-3 left-1/2 -translate-x-1/2">
              <span className="bg-gradient-success text-white text-xs font-semibold px-3 py-1 rounded-full">
                {plan.badge}
              </span>
            </div>
          )}

          <div className="text-center mb-6">
            <h3 className="text-xl font-nunito font-bold text-slate-800 mb-2">
              {plan.name}
            </h3>
            <div className="flex items-baseline justify-center gap-1">
              <span className="text-4xl font-bold text-slate-800">{plan.price}</span>
              <span className="text-slate-600">{plan.period}</span>
            </div>
            <p className="text-sm text-slate-600 mt-2">{plan.description}</p>
          </div>

          <ul className="space-y-3 mb-6">
            {plan.features.map((feature, index) => (
              <li key={index} className="flex items-center gap-2">
                {feature.included ? (
                  <Check className="w-5 h-5 text-green-600 flex-shrink-0" />
                ) : (
                  <X className="w-5 h-5 text-slate-400 flex-shrink-0" />
                )}
                <span
                  className={`text-sm ${
                    feature.included ? 'text-slate-700' : 'text-slate-400'
                  }`}
                >
                  {feature.name}
                </span>
              </li>
            ))}
          </ul>

          <button
            onClick={() => handleSelectPlan(plan.priceKey)}
            disabled={loading === plan.priceKey}
            className={`w-full py-3 px-4 rounded-xl font-semibold transition-all ${
              plan.popular || plan.badge
                ? 'bg-gradient-primary text-white hover:shadow-lg'
                : 'btn-clay'
            }`}
          >
            {loading === plan.priceKey ? (
              <Loader2 className="w-5 h-5 animate-spin mx-auto" />
            ) : plan.priceKey ? (
              'Get Started'
            ) : (
              'Start Free'
            )}
          </button>
        </div>
      ))}
    </div>
  );
}
```

**Step 3: Commit**

```bash
git add src/app/pricing/
git commit -m "feat(pricing): add pricing page with Stripe checkout"
```

---

## Phase 4: Feature Gating

### Task 4.1: Create User Plan Hook

**Files:**
- Create: `src/hooks/useUserPlan.ts`

**Step 1: Create the hook**

```typescript
// src/hooks/useUserPlan.ts
'use client';

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { PLAN_FEATURES, type PlanType, type PlanFeatures } from '@/types';

interface UserPlanState {
  plan: PlanType;
  features: PlanFeatures;
  loading: boolean;
  setPlan: (plan: PlanType) => void;
  fetchPlan: () => Promise<void>;
  canAccess: (feature: keyof PlanFeatures) => boolean;
}

export const useUserPlan = create<UserPlanState>()(
  persist(
    (set, get) => ({
      plan: 'free',
      features: PLAN_FEATURES.free,
      loading: true,

      setPlan: (plan) => {
        set({
          plan,
          features: PLAN_FEATURES[plan],
        });
      },

      fetchPlan: async () => {
        set({ loading: true });
        try {
          const res = await fetch('/api/user/plan');
          if (res.ok) {
            const data = await res.json();
            set({
              plan: data.plan,
              features: PLAN_FEATURES[data.plan as PlanType],
              loading: false,
            });
          } else {
            set({ loading: false });
          }
        } catch (error) {
          console.error('Failed to fetch user plan:', error);
          set({ loading: false });
        }
      },

      canAccess: (feature) => {
        return get().features[feature];
      },
    }),
    {
      name: 'user-plan',
      partialize: (state) => ({ plan: state.plan }),
    }
  )
);
```

**Step 2: Commit**

```bash
git add src/hooks/useUserPlan.ts
git commit -m "feat(hooks): add useUserPlan hook with Zustand"
```

---

### Task 4.2: Create User Plan API

**Files:**
- Create: `src/app/api/user/plan/route.ts`

**Step 1: Create the API**

```typescript
// src/app/api/user/plan/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@clerk/nextjs/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { users } from '@/lib/db/schema';
import { eq } from 'drizzle-orm';

export const runtime = 'edge';

export async function GET(request: NextRequest) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ plan: 'free' });
    }

    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const [user] = await db
      .select({ plan: users.plan })
      .from(users)
      .where(eq(users.id, userId));

    return NextResponse.json({ plan: user?.plan || 'free' });
  } catch (error) {
    console.error('Error fetching user plan:', error);
    return NextResponse.json({ plan: 'free' });
  }
}
```

**Step 2: Commit**

```bash
git add src/app/api/user/plan/route.ts
git commit -m "feat(api): add GET /api/user/plan endpoint"
```

---

### Task 4.3: Create Paywall Modal

**Files:**
- Create: `src/components/paywall/PaywallModal.tsx`
- Create: `src/components/paywall/index.ts`

**Step 1: Create PaywallModal component**

```typescript
// src/components/paywall/PaywallModal.tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { X, Crown, Loader2 } from 'lucide-react';

interface PaywallModalProps {
  isOpen: boolean;
  onClose: () => void;
  feature: string;
  description?: string;
}

export function PaywallModal({ isOpen, onClose, feature, description }: PaywallModalProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleUpgrade = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/stripe/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceKey: 'lifetime' }),
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      }
    } catch (error) {
      console.error('Checkout error:', error);
      router.push('/pricing');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="card-clay relative z-10 max-w-md w-full p-6 animate-in zoom-in-95">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-slate-400 hover:text-slate-600"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="text-center">
          <div className="w-16 h-16 bg-gradient-primary rounded-full flex items-center justify-center mx-auto mb-4">
            <Crown className="w-8 h-8 text-white" />
          </div>

          <h2 className="text-2xl font-nunito font-bold text-slate-800 mb-2">
            Unlock {feature}
          </h2>

          <p className="text-slate-600 mb-6">
            {description || `Upgrade to Pro to access ${feature.toLowerCase()} and boost your exam preparation.`}
          </p>

          <div className="bg-slate-50 rounded-xl p-4 mb-6">
            <div className="flex justify-center items-baseline gap-1 mb-2">
              <span className="text-3xl font-bold text-slate-800">£9.99</span>
              <span className="text-slate-600">one-time</span>
            </div>
            <p className="text-sm text-slate-600">Lifetime access to all Pro features</p>
          </div>

          <div className="space-y-3">
            <button
              onClick={handleUpgrade}
              disabled={loading}
              className="w-full py-3 px-4 rounded-xl font-semibold bg-gradient-primary text-white hover:shadow-lg transition-all"
            >
              {loading ? (
                <Loader2 className="w-5 h-5 animate-spin mx-auto" />
              ) : (
                'Upgrade to Pro'
              )}
            </button>

            <button
              onClick={() => router.push('/pricing')}
              className="w-full py-3 px-4 rounded-xl font-semibold text-slate-600 hover:bg-slate-100 transition-all"
            >
              View All Plans
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
```

**Step 2: Create index export**

```typescript
// src/components/paywall/index.ts
export { PaywallModal } from './PaywallModal';
```

**Step 3: Commit**

```bash
git add src/components/paywall/
git commit -m "feat(paywall): add PaywallModal component"
```

---

### Task 4.4: Add Paywall to Mock Exam Page

**Files:**
- Modify: `src/app/mock-exam/page.tsx`

**Step 1: Read current file**

Run: Read `src/app/mock-exam/page.tsx`

**Step 2: Add feature gating**

Wrap the "Start Exam" button with a plan check. If user is not Pro, show PaywallModal instead of starting exam.

**Step 3: Test feature gating**

- Free user clicks "Start Exam" → PaywallModal appears
- Pro user clicks "Start Exam" → Exam starts

**Step 4: Commit**

```bash
git add src/app/mock-exam/page.tsx
git commit -m "feat(mock-exam): add feature gating for free users"
```

---

## Phase 5: Ad Integration

### Task 5.1: Create Ad Banner Component

**Files:**
- Create: `src/components/ads/AdBanner.tsx`
- Create: `src/components/ads/index.ts`

**Step 1: Create AdBanner component**

```typescript
// src/components/ads/AdBanner.tsx
'use client';

import { useEffect, useRef } from 'react';
import { useUserPlan } from '@/hooks/useUserPlan';

interface AdBannerProps {
  slot: string;
  format?: 'auto' | 'horizontal' | 'vertical' | 'rectangle';
  className?: string;
}

declare global {
  interface Window {
    adsbygoogle: any[];
  }
}

export function AdBanner({ slot, format = 'auto', className = '' }: AdBannerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { canAccess, loading } = useUserPlan();

  useEffect(() => {
    if (loading) return;
    if (canAccess('noAds')) return;

    // Load AdSense script if not loaded
    const existingScript = document.querySelector('script[src*="adsbygoogle"]');
    if (!existingScript) {
      const script = document.createElement('script');
      script.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXXXX';
      script.async = true;
      script.crossOrigin = 'anonymous';
      document.head.appendChild(script);
    }

    // Push ad
    try {
      (window.adsbygoogle = window.adsbygoogle || []).push({});
    } catch (e) {
      console.error('AdSense error:', e);
    }
  }, [loading, canAccess]);

  // Don't render for Pro users or while loading
  if (loading || canAccess('noAds')) {
    return null;
  }

  return (
    <div ref={containerRef} className={`ad-container ${className}`}>
      <ins
        className="adsbygoogle"
        style={{ display: 'block' }}
        data-ad-client="ca-pub-XXXXXXXXXX"
        data-ad-slot={slot}
        data-ad-format={format}
        data-full-width-responsive="true"
      />
    </div>
  );
}
```

**Step 2: Create placeholder for development**

```typescript
// src/components/ads/AdPlaceholder.tsx
'use client';

import { useUserPlan } from '@/hooks/useUserPlan';

interface AdPlaceholderProps {
  className?: string;
  height?: string;
}

export function AdPlaceholder({ className = '', height = '90px' }: AdPlaceholderProps) {
  const { canAccess, loading } = useUserPlan();

  if (loading || canAccess('noAds')) {
    return null;
  }

  return (
    <div
      className={`bg-slate-100 border-2 border-dashed border-slate-300 rounded-lg flex items-center justify-center text-slate-400 text-sm ${className}`}
      style={{ height }}
    >
      Advertisement
    </div>
  );
}
```

**Step 3: Create index export**

```typescript
// src/components/ads/index.ts
export { AdBanner } from './AdBanner';
export { AdPlaceholder } from './AdPlaceholder';
```

**Step 4: Commit**

```bash
git add src/components/ads/
git commit -m "feat(ads): add AdBanner and AdPlaceholder components"
```

---

### Task 5.2: Add Ads to Practice Page

**Files:**
- Modify: `src/components/question/PracticeSession.tsx`

**Step 1: Read current file**

Run: Read `src/components/question/PracticeSession.tsx`

**Step 2: Add ad after every 5 questions**

Import AdPlaceholder, show it between questions when `questionIndex % 5 === 4`.

**Step 3: Test ads**

- Free user sees ad placeholders every 5 questions
- Pro user sees no ads

**Step 4: Commit**

```bash
git add src/components/question/PracticeSession.tsx
git commit -m "feat(practice): show ads every 5 questions for free users"
```

---

## Verification Checklist

After completing all tasks, verify:

- [ ] Questions seeded to D1: `wrangler d1 execute questionless-db --local --command="SELECT COUNT(*) FROM questions"` returns 200
- [ ] `/pricing` page loads with 3 plan options
- [ ] Clicking "Get Started" on Pro plan creates Stripe checkout
- [ ] Stripe webhook updates user plan after successful payment
- [ ] Free user sees PaywallModal when trying to access Mock Exam
- [ ] Pro user can access Mock Exam without paywall
- [ ] Free user sees ad placeholders in practice mode
- [ ] Pro user sees no ads
- [ ] Customer portal allows subscription management

---

## Environment Variables Required

Add to `.env.local`:

```
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
STRIPE_PRICE_PRO_MONTHLY=price_xxx
STRIPE_PRICE_PRO_ANNUAL=price_xxx
STRIPE_PRICE_LIFETIME=price_xxx
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

---

## File Summary

**New Files:**
- `scripts/seed-questions.ts`
- `scripts/seed-questions.sql`
- `src/lib/stripe.ts`
- `src/app/api/stripe/checkout/route.ts`
- `src/app/api/stripe/webhook/route.ts`
- `src/app/api/stripe/portal/route.ts`
- `src/app/api/user/plan/route.ts`
- `src/app/pricing/page.tsx`
- `src/app/pricing/PricingCards.tsx`
- `src/hooks/useUserPlan.ts`
- `src/components/paywall/PaywallModal.tsx`
- `src/components/paywall/index.ts`
- `src/components/ads/AdBanner.tsx`
- `src/components/ads/AdPlaceholder.tsx`
- `src/components/ads/index.ts`

**Modified Files:**
- `src/app/mock-exam/page.tsx`
- `src/components/question/PracticeSession.tsx`

---

## Estimated Completion

- **Phase 1**: 1 hour (seeding)
- **Phase 2**: 2-3 hours (Stripe integration)
- **Phase 3**: 1-2 hours (pricing page)
- **Phase 4**: 2 hours (feature gating)
- **Phase 5**: 1-2 hours (ad integration)

**Total: ~8-10 hours**
