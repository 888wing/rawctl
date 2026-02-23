import { auth, currentUser } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { getRequestContext } from "@cloudflare/next-on-pages";
import { getDb } from "@/lib/db";
import { users, subscriptions } from "@/lib/db/schema";
import { eq, and } from "drizzle-orm";

/**
 * Get the current authenticated user or redirect to sign-in
 */
export async function requireAuth() {
  const { userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  return userId;
}

/**
 * Get the current user's details
 */
export async function getUser() {
  const user = await currentUser();
  return user;
}

/**
 * Check if user has pro subscription
 */
export async function isPro(userId: string): Promise<boolean> {
  try {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const [sub] = await db
      .select()
      .from(subscriptions)
      .where(
        and(
          eq(subscriptions.userId, userId),
          eq(subscriptions.status, "active")
        )
      )
      .limit(1);

    return !!sub;
  } catch {
    return false;
  }
}

/**
 * Get user's plan type
 */
export type PlanType = "free" | "pro" | "pro_plus";

export async function getUserPlan(userId: string): Promise<PlanType> {
  try {
    const { env } = getRequestContext();
    const db = getDb(env.DB);

    const [user] = await db
      .select({ plan: users.plan })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (user?.plan === "pro" || user?.plan === "pro_plus") {
      return user.plan as PlanType;
    }

    return "free";
  } catch {
    return "free";
  }
}
