import Link from "next/link";
import {
  ArrowRight,
  Bot,
  Brain,
  CheckCircle,
  Clock,
  FileText,
  Landmark,
  Sparkles,
  Star,
  Target,
  Trophy,
  Users,
  Zap,
  BookOpen,
  ChevronRight,
  Check,
  X as XIcon,
  Minus,
} from "lucide-react";
import { TOPICS } from "@/lib/topics";
import { getAllExams, type ExamConfig } from "@/lib/exams";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

export const runtime = "edge";

// Topics from centralized config
const topics = TOPICS;

export default function HomePage() {
  const exams = getAllExams();
  const activeExams = exams.filter((e) => e.active);
  const comingSoonExams = exams.filter((e) => e.comingSoon);

  return (
    <main className="min-h-screen">
      {/* Hero Section */}
      <section className="bg-gradient-hero relative overflow-hidden">
        <div className="absolute top-20 left-10 w-72 h-72 bg-primary/10 rounded-full blur-3xl" />
        <div className="absolute bottom-10 right-10 w-96 h-96 bg-purple-400/10 rounded-full blur-3xl" />

        <div className="container mx-auto px-4 py-20 md:py-28 text-center relative">
          <Badge
            variant="secondary"
            className="mb-6 px-4 py-2 text-sm font-medium shadow-clay-sm"
          >
            <Star className="h-3.5 w-3.5 mr-1.5 text-amber-500 fill-amber-500" />
            Trusted by 10,000+ learners
          </Badge>

          <h1 className="text-4xl md:text-6xl font-bold text-gray-900 mb-6 font-nunito tracking-tight">
            Question Less,{" "}
            <span className="text-gradient">Score More</span>
          </h1>

          <p className="text-xl text-muted-foreground mb-10 max-w-2xl mx-auto leading-relaxed">
            AI-powered practice tests for UK public exams. Pass your{" "}
            <span className="font-semibold text-foreground">citizenship</span>,{" "}
            <span className="font-semibold text-foreground">driving</span>, and{" "}
            <span className="font-semibold text-foreground">professional</span>{" "}
            exams with confidence.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button
              asChild
              size="lg"
              className="btn-clay bg-gradient-primary text-white border-0 text-lg px-8 h-14"
            >
              <Link href="/practice">
                <Sparkles className="h-5 w-5 mr-2" />
                Start Practicing Free
              </Link>
            </Button>
            <Button
              asChild
              variant="outline"
              size="lg"
              className="shadow-clay-sm h-14 text-lg px-8"
            >
              <Link href="/exams">
                <BookOpen className="h-5 w-5 mr-2" />
                Browse All Exams
              </Link>
            </Button>
          </div>

          <div className="flex flex-wrap justify-center gap-8 mt-12 text-sm text-muted-foreground">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-success-500" />
              <span>No credit card required</span>
            </div>
            <div className="flex items-center gap-2">
              <Users className="h-4 w-4 text-primary" />
              <span>Join 10,000+ learners</span>
            </div>
            <div className="flex items-center gap-2">
              <Clock className="h-4 w-4 text-amber-500" />
              <span>Pass in 2 weeks</span>
            </div>
          </div>
        </div>
      </section>

      {/* Exam Cards Section */}
      <section className="container mx-auto px-4 py-20">
        <div className="text-center mb-12">
          <Badge variant="outline" className="mb-4">
            Exams
          </Badge>
          <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
            Choose Your Exam
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Practice for the UK&apos;s most important public exams, all in one
            place
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-6 max-w-4xl mx-auto mb-8">
          {activeExams.map((exam) => (
            <ActiveExamCard key={exam.slug} exam={exam} />
          ))}
        </div>

        {comingSoonExams.length > 0 && (
          <div className="grid md:grid-cols-3 gap-4 max-w-4xl mx-auto">
            {comingSoonExams.map((exam) => (
              <ComingSoonExamCard key={exam.slug} exam={exam} />
            ))}
          </div>
        )}

        <div className="text-center mt-8">
          <Link
            href="/exams"
            className="inline-flex items-center text-primary font-medium hover:underline"
          >
            View all exams
            <ChevronRight className="h-4 w-4 ml-1" />
          </Link>
        </div>
      </section>

      {/* How It Works */}
      <section className="bg-muted/30 py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <Badge variant="outline" className="mb-4">
              Simple Process
            </Badge>
            <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
              How It Works
            </h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              Three simple steps to exam success
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8 max-w-4xl mx-auto relative">
            {/* Connecting line (desktop only) */}
            <div className="hidden md:block absolute top-16 left-[20%] right-[20%] h-0.5 bg-gradient-to-r from-primary/20 via-primary/40 to-primary/20" />

            <StepCard
              number={1}
              title="Choose Your Exam"
              description="Pick from UK citizenship, driving theory, CSCS, or professional exams"
              icon={BookOpen}
            />
            <StepCard
              number={2}
              title="Practice Smart"
              description="AI adapts to your weaknesses. Spaced repetition ensures you remember"
              icon={Brain}
            />
            <StepCard
              number={3}
              title="Pass With Confidence"
              description="Take mock exams, track your progress, and walk into test day prepared"
              icon={Trophy}
            />
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="container mx-auto px-4 py-20">
        <div className="text-center mb-16">
          <Badge variant="outline" className="mb-4">
            Features
          </Badge>
          <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
            Why Questionless?
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Our smart learning system adapts to you, helping you focus on what
            matters most
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          <FeatureCard
            title="AI-Powered Learning"
            description="Personalized questions generated by AI to target your weak areas and accelerate learning"
            icon={Bot}
            color="bg-primary/10 text-primary"
          />
          <FeatureCard
            title="Smart Review"
            description="Spaced repetition algorithm ensures you remember what you learn for the long term"
            icon={Brain}
            color="bg-purple-100 text-purple-600"
          />
          <FeatureCard
            title="Real Exam Simulation"
            description="Practice with timed mock exams that mirror the official test format"
            icon={FileText}
            color="bg-success-100 text-success-600"
          />
        </div>
      </section>

      {/* Topics Section — Life in the UK Quick Access */}
      <section className="bg-muted/30 py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <Badge variant="outline" className="mb-4">
              Life in the UK Test
            </Badge>
            <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
              Topics Covered
            </h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              Master all {topics.length} topic areas of the Life in the UK Test
            </p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-4 max-w-4xl mx-auto">
            {topics.map((topic) => {
              const Icon = topic.icon;
              return (
                <Link
                  key={topic.slug}
                  href={`/practice/${topic.slug}`}
                  className="block group"
                >
                  <div className="card-clay p-5 text-center h-full">
                    <div
                      className={`inline-flex p-3 rounded-xl mb-3 ${topic.color} transition-transform group-hover:scale-110`}
                    >
                      <Icon className="h-6 w-6" />
                    </div>
                    <p className="font-semibold text-sm">{topic.name}</p>
                  </div>
                </Link>
              );
            })}
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="container mx-auto px-4 py-20">
        <div className="card-clay-static p-8 md:p-12">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
            <StatItem value="500+" label="Practice Questions" icon={FileText} />
            <StatItem value="4" label="UK Exams" icon={BookOpen} />
            <StatItem
              value={String(topics.length)}
              label="Topic Areas"
              icon={Landmark}
            />
            <StatItem value="75%" label="Pass Rate Required" icon={Trophy} />
          </div>
        </div>
      </section>

      {/* Comparison Table */}
      <section className="bg-muted/30 py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <Badge variant="outline" className="mb-4">
              Compare
            </Badge>
            <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
              Why Choose Questionless?
            </h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              See how we compare to traditional study methods
            </p>
          </div>

          <div className="max-w-3xl mx-auto overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-4 pr-4 font-semibold text-sm text-muted-foreground">
                    Feature
                  </th>
                  <th className="py-4 px-4 text-center">
                    <div className="inline-flex flex-col items-center">
                      <div className="bg-gradient-primary p-2 rounded-xl mb-2">
                        <Zap className="h-4 w-4 text-white" />
                      </div>
                      <span className="font-bold font-nunito text-primary">
                        Questionless
                      </span>
                    </div>
                  </th>
                  <th className="py-4 px-4 text-center">
                    <span className="font-medium text-sm text-muted-foreground">
                      Textbooks
                    </span>
                  </th>
                  <th className="py-4 px-4 text-center">
                    <span className="font-medium text-sm text-muted-foreground">
                      Other Apps
                    </span>
                  </th>
                </tr>
              </thead>
              <tbody className="text-sm">
                <ComparisonRow
                  feature="Free to start"
                  questionless="yes"
                  textbooks="no"
                  others="partial"
                />
                <ComparisonRow
                  feature="AI-powered questions"
                  questionless="yes"
                  textbooks="no"
                  others="no"
                />
                <ComparisonRow
                  feature="Spaced repetition"
                  questionless="yes"
                  textbooks="no"
                  others="partial"
                />
                <ComparisonRow
                  feature="Mock exam simulation"
                  questionless="yes"
                  textbooks="no"
                  others="yes"
                />
                <ComparisonRow
                  feature="Multiple UK exams"
                  questionless="yes"
                  textbooks="no"
                  others="no"
                />
                <ComparisonRow
                  feature="Progress tracking"
                  questionless="yes"
                  textbooks="no"
                  others="partial"
                />
                <ComparisonRow
                  feature="Mobile friendly"
                  questionless="yes"
                  textbooks="no"
                  others="yes"
                />
                <ComparisonRow
                  feature="Instant explanations"
                  questionless="yes"
                  textbooks="partial"
                  others="partial"
                />
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <Badge variant="outline" className="mb-4">
              Success Stories
            </Badge>
            <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
              Join Our Community
            </h2>
            <p className="text-muted-foreground max-w-xl mx-auto">
              Thousands of learners have passed their exams with Questionless
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-5xl mx-auto">
            <TestimonialCard
              quote="Passed on my first attempt! The spaced repetition really helped me remember difficult dates."
              author="Maria S."
              role="Life in the UK — Passed Dec 2024"
            />
            <TestimonialCard
              quote="The mock exams were exactly like the real test. I felt so prepared on exam day."
              author="James K."
              role="Life in the UK — Passed Jan 2025"
            />
            <TestimonialCard
              quote="Best UK citizenship test prep app. The AI questions targeted exactly what I needed to learn."
              author="Priya M."
              role="Life in the UK — Passed Nov 2024"
            />
            <TestimonialCard
              quote="I was struggling with British history dates but the smart review kept bringing them back until I knew them cold."
              author="Ahmed R."
              role="Life in the UK — Passed Feb 2025"
            />
            <TestimonialCard
              quote="Studied on my commute every day for two weeks. The mobile experience is perfect."
              author="Lin W."
              role="Life in the UK — Passed Jan 2025"
            />
            <TestimonialCard
              quote="The topic breakdown helped me focus on my weakest areas. Went from 50% to 90% in one week."
              author="David O."
              role="Life in the UK — Passed Dec 2024"
            />
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section className="bg-muted/30 py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <Badge variant="outline" className="mb-4">
              FAQ
            </Badge>
            <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
              Frequently Asked Questions
            </h2>
          </div>

          <div className="max-w-3xl mx-auto">
            <Accordion type="single" collapsible className="space-y-3">
              {FAQ_ITEMS.map((faq, i) => (
                <AccordionItem
                  key={i}
                  value={`faq-${i}`}
                  className="card-clay-static px-6 border-0"
                >
                  <AccordionTrigger className="text-left font-semibold font-nunito hover:no-underline py-5">
                    {faq.question}
                  </AccordionTrigger>
                  <AccordionContent className="text-muted-foreground pb-5">
                    {faq.answer}
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </div>

          {/* FAQ Schema */}
          <script
            type="application/ld+json"
            dangerouslySetInnerHTML={{
              __html: JSON.stringify({
                "@context": "https://schema.org",
                "@type": "FAQPage",
                mainEntity: FAQ_ITEMS.map((faq) => ({
                  "@type": "Question",
                  name: faq.question,
                  acceptedAnswer: {
                    "@type": "Answer",
                    text: faq.answer,
                  },
                })),
              }),
            }}
          />
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20">
        <div className="container mx-auto px-4">
          <div className="card-clay-static bg-gradient-primary text-white p-12 md:p-16 text-center">
            <h2 className="text-3xl md:text-4xl font-bold font-nunito mb-4">
              Ready to Pass Your Exam?
            </h2>
            <p className="text-white/80 mb-8 text-lg max-w-xl mx-auto">
              Join thousands of successful applicants who passed with
              Questionless
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Button
                asChild
                size="lg"
                variant="secondary"
                className="btn-clay h-14 text-lg px-8"
              >
                <Link href="/practice">
                  <Sparkles className="h-5 w-5 mr-2" />
                  Start Free Practice
                </Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="h-14 text-lg px-8 border-white/30 text-white hover:bg-white/10 hover:text-white"
              >
                <Link href="/exams">Browse All Exams</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}

// ─── Sub-components ──────────────────────────────────────────────

function ActiveExamCard({ exam }: { exam: ExamConfig }) {
  const Icon = exam.icon;
  return (
    <Link href="/practice" className="block group">
      <div className="card-clay p-6 h-full">
        <div className="flex items-start gap-4 mb-4">
          <div
            className={`p-3 rounded-xl ${exam.color} transition-transform group-hover:scale-110`}
          >
            <Icon className="h-7 w-7" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold font-nunito mb-1">{exam.name}</h3>
            <p className="text-sm text-muted-foreground">{exam.tagline}</p>
          </div>
        </div>
        <div className="flex flex-wrap gap-2 mb-4">
          <Badge variant="secondary" className="text-xs">
            <FileText className="h-3 w-3 mr-1" />
            {exam.examQuestions} questions
          </Badge>
          <Badge variant="secondary" className="text-xs">
            <Clock className="h-3 w-3 mr-1" />
            {exam.examMinutes} min
          </Badge>
          <Badge variant="secondary" className="text-xs">
            {exam.passPercent}% to pass
          </Badge>
        </div>
        <span className="flex items-center text-sm font-medium text-primary group-hover:underline">
          Start practicing
          <ArrowRight className="h-4 w-4 ml-1 transition-transform group-hover:translate-x-1" />
        </span>
      </div>
    </Link>
  );
}

function ComingSoonExamCard({ exam }: { exam: ExamConfig }) {
  const Icon = exam.icon;
  return (
    <div className="card-clay-static p-5 h-full opacity-80">
      <div className="flex items-center gap-3 mb-2">
        <div className={`p-2.5 rounded-xl ${exam.color}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="text-sm font-bold font-nunito truncate">
            {exam.name}
          </h3>
          <p className="text-xs text-muted-foreground">{exam.tagline}</p>
        </div>
      </div>
      <Badge variant="outline" className="text-xs">
        Coming Soon
      </Badge>
    </div>
  );
}

function StepCard({
  number,
  title,
  description,
  icon: Icon,
}: {
  number: number;
  title: string;
  description: string;
  icon: React.ElementType;
}) {
  return (
    <div className="card-clay p-6 text-center relative z-10">
      <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-gradient-primary text-white font-bold text-lg font-nunito mb-4">
        {number}
      </div>
      <div className="inline-flex p-3 rounded-xl bg-primary/10 text-primary mb-4 ml-2">
        <Icon className="h-6 w-6" />
      </div>
      <h3 className="text-lg font-bold font-nunito mb-2">{title}</h3>
      <p className="text-muted-foreground text-sm leading-relaxed">
        {description}
      </p>
    </div>
  );
}

function FeatureCard({
  title,
  description,
  icon: Icon,
  color,
}: {
  title: string;
  description: string;
  icon: React.ElementType;
  color: string;
}) {
  return (
    <div className="card-clay p-6 text-center h-full">
      <div className={`inline-flex p-4 rounded-2xl mb-4 ${color}`}>
        <Icon className="h-7 w-7" />
      </div>
      <h3 className="text-xl font-bold font-nunito mb-3">{title}</h3>
      <p className="text-muted-foreground leading-relaxed">{description}</p>
    </div>
  );
}

function StatItem({
  value,
  label,
  icon: Icon,
}: {
  value: string;
  label: string;
  icon: React.ElementType;
}) {
  return (
    <div className="flex flex-col items-center">
      <div className="bg-primary/10 p-3 rounded-xl mb-3">
        <Icon className="h-6 w-6 text-primary" />
      </div>
      <p className="text-4xl font-bold text-primary mb-1 font-nunito">
        {value}
      </p>
      <p className="text-muted-foreground text-sm">{label}</p>
    </div>
  );
}

function TestimonialCard({
  quote,
  author,
  role,
}: {
  quote: string;
  author: string;
  role: string;
}) {
  return (
    <div className="card-clay p-6 h-full flex flex-col">
      <div className="flex gap-1 mb-4">
        {[...Array(5)].map((_, i) => (
          <Star key={i} className="h-4 w-4 text-amber-400 fill-amber-400" />
        ))}
      </div>
      <p className="text-muted-foreground flex-1 mb-4 italic">
        &ldquo;{quote}&rdquo;
      </p>
      <div>
        <p className="font-semibold">{author}</p>
        <p className="text-xs text-muted-foreground">{role}</p>
      </div>
    </div>
  );
}

function ComparisonRow({
  feature,
  questionless,
  textbooks,
  others,
}: {
  feature: string;
  questionless: "yes" | "no" | "partial";
  textbooks: "yes" | "no" | "partial";
  others: "yes" | "no" | "partial";
}) {
  const renderCell = (value: "yes" | "no" | "partial") => {
    if (value === "yes")
      return <Check className="h-5 w-5 text-green-500 mx-auto" />;
    if (value === "no")
      return <XIcon className="h-5 w-5 text-red-400 mx-auto" />;
    return <Minus className="h-5 w-5 text-amber-400 mx-auto" />;
  };

  return (
    <tr className="border-b last:border-0">
      <td className="py-3.5 pr-4 font-medium">{feature}</td>
      <td className="py-3.5 px-4 text-center bg-primary/5">
        {renderCell(questionless)}
      </td>
      <td className="py-3.5 px-4 text-center">{renderCell(textbooks)}</td>
      <td className="py-3.5 px-4 text-center">{renderCell(others)}</td>
    </tr>
  );
}

// ─── FAQ Data ────────────────────────────────────────────────────

const FAQ_ITEMS = [
  {
    question: "Is Questionless really free?",
    answer:
      "Yes! Practice questions are completely free with no time limit. The Pro plan unlocks mock exams, spaced repetition review, and detailed progress tracking for serious learners.",
  },
  {
    question: "Which exams does Questionless cover?",
    answer:
      "We currently offer full practice for the Life in the UK Test with 500+ questions. UK Driving Theory, CSCS Health & Safety, and OET exams are coming soon.",
  },
  {
    question: "How does AI-powered learning work?",
    answer:
      "Our AI generates personalised practice questions that target your weak areas. Combined with spaced repetition, the system ensures you spend time on topics that need the most attention.",
  },
  {
    question: "Are the questions similar to the real exam?",
    answer:
      "Our questions are designed to match the format, difficulty, and topic coverage of official exams. Mock exams simulate the real test with the same number of questions and time limit.",
  },
  {
    question: "How long does it take to prepare?",
    answer:
      "Most learners who use Questionless regularly pass within 2-3 weeks. The spaced repetition system helps you retain information efficiently so you can prepare faster.",
  },
  {
    question: "Can I use Questionless on my phone?",
    answer:
      "Absolutely. Questionless is fully responsive and works on any device. Many learners study on their commute or during breaks using their mobile phone.",
  },
  {
    question: "What happens if I fail my exam?",
    answer:
      "You can continue practising for free. Our progress tracking shows exactly which topics need more work, so you can focus your revision and pass next time.",
  },
];
