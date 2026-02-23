'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { QuestionCard, type QuestionData } from '@/components/question/QuestionCard';
import { Confetti } from '@/components/question/Confetti';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  RotateCcw,
  CheckCircle2,
  XCircle,
  ArrowRight,
  Brain,
  Trophy,
  Loader2,
} from 'lucide-react';
import Link from 'next/link';

export const runtime = 'edge';

interface AnswerRecord {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
}

export default function ReviewSessionPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [questions, setQuestions] = useState<QuestionData[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState<AnswerRecord[]>([]);
  const [isComplete, setIsComplete] = useState(false);
  const [showConfetti, setShowConfetti] = useState(false);

  // Fetch due questions
  useEffect(() => {
    async function fetchDueQuestions() {
      try {
        const res = await fetch('/api/user/review/due?limit=20');
        if (!res.ok) throw new Error('Failed to fetch reviews');
        const data = await res.json() as { questions: QuestionData[] };

        if (data.questions.length === 0) {
          setError('no-questions');
          setLoading(false);
          return;
        }

        setQuestions(data.questions);
        setLoading(false);
      } catch {
        setError('Failed to load review questions');
        setLoading(false);
      }
    }
    fetchDueQuestions();
  }, []);

  const handleAnswer = useCallback(
    async (questionId: string, selectedIndex: number, isCorrect: boolean) => {
      setAnswers((prev) => [...prev, { questionId, selectedIndex, isCorrect }]);

      // Update SR record and save answer
      try {
        await Promise.all([
          fetch('/api/user/review', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ questionId, isCorrect }),
          }),
          fetch('/api/user/answers', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ questionId, selectedIndex, isCorrect }),
          }),
        ]);
      } catch (err) {
        console.error('Failed to save review:', err);
      }
    },
    []
  );

  const handleNext = useCallback(() => {
    if (currentIndex < questions.length - 1) {
      setCurrentIndex((prev) => prev + 1);
    } else {
      setIsComplete(true);
      const correctCount = answers.filter((a) => a.isCorrect).length;
      if (correctCount / questions.length >= 0.75) {
        setShowConfetti(true);
        setTimeout(() => setShowConfetti(false), 5000);
      }
    }
  }, [currentIndex, questions.length, answers]);

  if (loading) {
    return (
      <div className="min-h-screen bg-muted/30 flex items-center justify-center p-4">
        <div className="card-clay-static p-8 text-center">
          <Loader2 className="h-12 w-12 text-primary animate-spin mx-auto mb-4" />
          <p className="text-muted-foreground">Loading your review questions...</p>
        </div>
      </div>
    );
  }

  if (error === 'no-questions') {
    return (
      <div className="min-h-screen bg-muted/30 flex items-center justify-center p-4">
        <div className="card-clay-static p-8 text-center max-w-md">
          <div className="bg-green-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 className="h-8 w-8 text-green-600" />
          </div>
          <h1 className="text-2xl font-bold font-nunito mb-2">All Caught Up!</h1>
          <p className="text-muted-foreground mb-6">
            No questions are due for review right now. Keep practicing to build your review queue!
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <Button asChild className="btn-clay bg-gradient-primary text-white border-0">
              <Link href="/practice">Practice More</Link>
            </Button>
            <Button asChild variant="outline" className="shadow-clay-sm">
              <Link href="/dashboard">Dashboard</Link>
            </Button>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-muted/30 flex items-center justify-center p-4">
        <div className="card-clay-static p-8 text-center">
          <p className="text-red-600 mb-4">{error}</p>
          <Button onClick={() => router.push('/review')} className="btn-clay">
            Back to Review
          </Button>
        </div>
      </div>
    );
  }

  if (isComplete) {
    const correctCount = answers.filter((a) => a.isCorrect).length;
    const percentage = Math.round((correctCount / questions.length) * 100);

    return (
      <div className="min-h-screen bg-muted/30 p-4">
        {showConfetti && <Confetti />}
        <div className="max-w-2xl mx-auto">
          <div className="card-clay-static p-8 text-center">
            <div
              className={`w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-4 ${
                percentage >= 75 ? 'bg-green-100' : 'bg-amber-100'
              }`}
            >
              {percentage >= 75 ? (
                <Trophy className="h-10 w-10 text-green-600" />
              ) : (
                <Brain className="h-10 w-10 text-amber-600" />
              )}
            </div>

            <h1 className="text-2xl font-bold font-nunito mb-2">Review Complete!</h1>
            <div className="text-4xl font-bold font-nunito mb-2">
              {correctCount}/{questions.length}
            </div>
            <p className="text-muted-foreground mb-2">{percentage}% accuracy</p>

            <div className="flex items-center justify-center gap-6 mb-6">
              <div className="flex items-center gap-1.5 text-green-600">
                <CheckCircle2 className="h-5 w-5" />
                <span className="font-medium">{correctCount} correct</span>
              </div>
              <div className="flex items-center gap-1.5 text-red-500">
                <XCircle className="h-5 w-5" />
                <span className="font-medium">{questions.length - correctCount} wrong</span>
              </div>
            </div>

            <p className="text-sm text-muted-foreground mb-6">
              Questions you got wrong will appear again sooner in your next review.
            </p>

            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <Button asChild className="btn-clay bg-gradient-primary text-white border-0">
                <Link href="/dashboard">
                  Dashboard
                  <ArrowRight className="h-4 w-4 ml-2" />
                </Link>
              </Button>
              <Button asChild variant="outline" className="shadow-clay-sm">
                <Link href="/practice">Practice More</Link>
              </Button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const currentQuestion = questions[currentIndex];

  return (
    <div className="min-h-screen bg-muted/30 p-4">
      <div className="max-w-2xl mx-auto">
        {/* Header */}
        <div className="card-clay-static p-4 mb-4">
          <div className="flex justify-between items-center mb-2">
            <Badge variant="outline" className="gap-1">
              <RotateCcw className="h-3 w-3" />
              Smart Review
            </Badge>
            <span className="text-sm text-muted-foreground">
              {currentIndex + 1} of {questions.length}
            </span>
          </div>
          <div className="h-2 bg-muted rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-primary transition-all duration-300"
              style={{ width: `${(currentIndex / questions.length) * 100}%` }}
            />
          </div>
        </div>

        {/* Question */}
        <QuestionCard
          question={currentQuestion}
          questionNumber={currentIndex + 1}
          totalQuestions={questions.length}
          onAnswer={handleAnswer}
          onNext={handleNext}
        />
      </div>
    </div>
  );
}
