import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';
import { getDb } from '@/lib/db';
import { users, subscriptions } from '@/lib/db/schema';
import { eq } from 'drizzle-orm';
import Stripe from 'stripe';

export const runtime = 'edge';

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error('STRIPE_SECRET_KEY not set');
  return new Stripe(key, { apiVersion: '2023-10-16' });
}

export async function POST(request: NextRequest) {
  const body = await request.text();
  const signature = request.headers.get('stripe-signature');

  if (!signature) {
    return NextResponse.json({ error: 'Missing signature' }, { status: 400 });
  }

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return NextResponse.json({ error: 'Webhook secret not configured' }, { status: 500 });
  }

  let event: Stripe.Event;

  try {
    const stripe = getStripe();
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
        const userId = session.metadata?.userId || session.client_reference_id;
        const plan = session.metadata?.plan || 'pro_monthly';

        if (!userId) break;

        const planType = plan.includes('lifetime') ? 'pro_plus' : 'pro';

        if (session.mode === 'subscription' && session.subscription) {
          // Subscription payment
          await db
            .insert(subscriptions)
            .values({
              id: session.subscription as string,
              userId,
              plan: planType,
              status: 'active',
              currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            })
            .onConflictDoUpdate({
              target: subscriptions.id,
              set: { status: 'active', plan: planType },
            });
        } else {
          // One-time payment (lifetime)
          const subId = `lifetime_${userId}_${Date.now()}`;
          await db
            .insert(subscriptions)
            .values({
              id: subId,
              userId,
              plan: 'pro_plus',
              status: 'active',
              currentPeriodEnd: '2099-12-31T23:59:59.000Z',
            })
            .onConflictDoNothing();
        }

        // Update user plan
        await db
          .update(users)
          .set({ plan: planType, stripeCustomerId: session.customer as string })
          .where(eq(users.id, userId));

        break;
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription;
        const subId = subscription.id;

        await db
          .update(subscriptions)
          .set({
            status: subscription.status === 'active' ? 'active' : 'past_due',
            currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
          })
          .where(eq(subscriptions.id, subId));

        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        const subId = subscription.id;

        // Mark subscription as canceled
        await db
          .update(subscriptions)
          .set({ status: 'canceled' })
          .where(eq(subscriptions.id, subId));

        // Downgrade user to free
        const [sub] = await db
          .select({ userId: subscriptions.userId })
          .from(subscriptions)
          .where(eq(subscriptions.id, subId));

        if (sub) {
          await db
            .update(users)
            .set({ plan: 'free' })
            .where(eq(users.id, sub.userId));
        }

        break;
      }
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('Webhook processing error:', error);
    return NextResponse.json({ error: 'Webhook processing failed' }, { status: 500 });
  }
}
