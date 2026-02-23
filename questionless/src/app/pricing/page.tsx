import Link from "next/link";
import { auth } from "@clerk/nextjs/server";
import {
  Check,
  X,
  Crown,
  Sparkles,
  Shield,
  Zap,
  Star,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { PRICING, PLAN_FEATURES } from "@/types";

export const runtime = "edge";

const PLAN_DETAILS = [
  {
    name: "Free",
    key: "free" as const,
    description: "Get started with basic practice",
    price: 0,
    interval: "",
    highlighted: false,
    cta: "Current Plan",
    icon: Sparkles,
  },
  {
    name: "Pro",
    key: "pro" as const,
    description: "Everything you need to pass",
    price: PRICING.pro_monthly.price,
    interval: "/month",
    highlighted: true,
    cta: "Upgrade to Pro",
    icon: Crown,
    badge: "Most Popular",
    annualPrice: PRICING.pro_annual.price,
  },
  {
    name: "Lifetime",
    key: "pro_plus" as const,
    description: "One-time payment, forever access",
    price: PRICING.lifetime.price,
    interval: " once",
    highlighted: false,
    cta: "Get Lifetime Access",
    icon: Shield,
  },
];

const FEATURE_LIST = [
  { label: "Unlimited practice questions", key: "unlimitedPractice" },
  { label: "Mock exams (24 questions, timed)", key: "mockExams" },
  { label: "Wrong answer review", key: "wrongAnswerReview" },
  { label: "Spaced repetition system", key: "spacedRepetition" },
  { label: "Ad-free experience", key: "noAds" },
  { label: "Detailed progress analytics", key: "detailedProgress" },
] as const;

export default async function PricingPage() {
  const { userId } = await auth();

  return (
    <main className="min-h-screen bg-muted/30">
      <div className="container mx-auto px-4 py-12 max-w-5xl">
        {/* Header */}
        <div className="text-center mb-12">
          <Badge variant="outline" className="mb-4">
            <Zap className="h-3 w-3 mr-1" />
            Simple Pricing
          </Badge>
          <h1 className="text-3xl md:text-4xl font-bold font-nunito text-gray-900 mb-3">
            Pass Your Life in the UK Test
          </h1>
          <p className="text-muted-foreground text-lg max-w-xl mx-auto">
            Choose the plan that works for you. Upgrade anytime to unlock all features.
          </p>
        </div>

        {/* Pricing Cards */}
        <div className="grid md:grid-cols-3 gap-6 mb-12">
          {PLAN_DETAILS.map((plan) => {
            const Icon = plan.icon;
            const features = PLAN_FEATURES[plan.key];

            return (
              <div
                key={plan.key}
                className={`relative card-clay-static p-6 flex flex-col ${
                  plan.highlighted
                    ? "ring-2 ring-primary md:scale-105 md:-my-2"
                    : ""
                }`}
              >
                {plan.badge && (
                  <Badge className="absolute -top-3 left-1/2 -translate-x-1/2 bg-gradient-primary text-white border-0 px-4">
                    <Star className="h-3 w-3 mr-1" />
                    {plan.badge}
                  </Badge>
                )}

                <div className="mb-6">
                  <div
                    className={`inline-flex p-3 rounded-xl mb-4 ${
                      plan.highlighted
                        ? "bg-primary/10"
                        : "bg-muted/50"
                    }`}
                  >
                    <Icon
                      className={`h-6 w-6 ${
                        plan.highlighted ? "text-primary" : "text-muted-foreground"
                      }`}
                    />
                  </div>
                  <h2 className="text-xl font-bold font-nunito">{plan.name}</h2>
                  <p className="text-sm text-muted-foreground mt-1">
                    {plan.description}
                  </p>
                </div>

                <div className="mb-6">
                  <div className="flex items-baseline gap-1">
                    <span className="text-4xl font-bold font-nunito">
                      {plan.price === 0 ? "Free" : `£${plan.price}`}
                    </span>
                    {plan.interval && (
                      <span className="text-muted-foreground">{plan.interval}</span>
                    )}
                  </div>
                  {plan.annualPrice && (
                    <p className="text-sm text-muted-foreground mt-1">
                      or £{plan.annualPrice}/year (save 50%)
                    </p>
                  )}
                </div>

                <ul className="space-y-3 mb-8 flex-1">
                  {FEATURE_LIST.map(({ label, key }) => {
                    const hasFeature = features[key];
                    return (
                      <li key={key} className="flex items-start gap-2">
                        {hasFeature ? (
                          <Check className="h-5 w-5 text-green-500 shrink-0 mt-0.5" />
                        ) : (
                          <X className="h-5 w-5 text-muted-foreground/40 shrink-0 mt-0.5" />
                        )}
                        <span
                          className={
                            hasFeature
                              ? "text-sm"
                              : "text-sm text-muted-foreground/60"
                          }
                        >
                          {label}
                        </span>
                      </li>
                    );
                  })}
                </ul>

                {plan.key === "free" ? (
                  <Button
                    variant="outline"
                    className="w-full shadow-clay-sm"
                    disabled={!!userId}
                    asChild={!userId}
                  >
                    {userId ? (
                      <span>Current Plan</span>
                    ) : (
                      <Link href="/sign-up">Sign Up Free</Link>
                    )}
                  </Button>
                ) : (
                  <Button
                    asChild
                    className={`w-full ${
                      plan.highlighted
                        ? "btn-clay bg-gradient-primary text-white border-0"
                        : "btn-clay"
                    }`}
                  >
                    <Link
                      href={
                        userId
                          ? `/api/checkout?plan=${plan.key === "pro" ? "pro_monthly" : "lifetime"}`
                          : "/sign-up"
                      }
                    >
                      {userId ? plan.cta : "Sign Up to Upgrade"}
                    </Link>
                  </Button>
                )}
              </div>
            );
          })}
        </div>

        {/* FAQ */}
        <div className="card-clay-static p-6 md:p-8">
          <h2 className="text-xl font-bold font-nunito mb-6 text-center">
            Frequently Asked Questions
          </h2>
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <h3 className="font-semibold mb-1">What is the Life in the UK test?</h3>
              <p className="text-sm text-muted-foreground">
                It&apos;s a compulsory test for anyone seeking British citizenship or settlement.
                You need to score 75% (18 out of 24 questions) to pass.
              </p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">Can I cancel anytime?</h3>
              <p className="text-sm text-muted-foreground">
                Yes! Monthly subscriptions can be cancelled at any time. You&apos;ll retain
                access until the end of your billing period.
              </p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">How does the lifetime plan work?</h3>
              <p className="text-sm text-muted-foreground">
                Pay once, use forever. You get all Pro features with no recurring charges.
                Perfect if you want peace of mind.
              </p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">Is the free plan enough to pass?</h3>
              <p className="text-sm text-muted-foreground">
                The free plan gives you unlimited practice questions. Pro adds mock exams,
                spaced repetition, and analytics to boost your chances.
              </p>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
