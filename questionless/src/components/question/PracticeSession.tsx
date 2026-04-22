"use client";

import { useState, useCallback, useEffect } from "react";
import { QuestionCard, QuestionData } from "./QuestionCard";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  CheckCircle2,
  XCircle,
  RotateCcw,
  Trophy,
  Target,
  PartyPopper,
  Sparkles,
} from "lucide-react";
import Link from "next/link";
import { Confetti } from "./Confetti";

interface PracticeSessionProps {
  questions: QuestionData[];
  topic?: string;
  sessionKey?: string; // For localStorage persistence
}

interface AnswerRecord {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
  timestamp: number;
}

export function PracticeSession({ questions, topic, sessionKey }: PracticeSessionProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState<AnswerRecord[]>([]);
  const [isComplete, setIsComplete] = useState(false);
  const [showConfetti, setShowConfetti] = useState(false);

  // Load session from localStorage
  useEffect(() => {
    if (sessionKey && typeof window !== "undefined") {
      const saved = localStorage.getItem(`practice_${sessionKey}`);
      if (saved) {
        try {
          const data = JSON.parse(saved);
          if (data.answers && data.currentIndex !== undefined) {
            setAnswers(data.answers);
            setCurrentIndex(data.currentIndex);
            if (data.currentIndex >= questions.length) {
              setIsComplete(true);
            }
          }
        } catch (e) {
          console.error("Failed to load session:", e);
        }
      }
    }
  }, [sessionKey, questions.length]);

  // Save session to localStorage
  useEffect(() => {
    if (sessionKey && typeof window !== "undefined" && answers.length > 0) {
      localStorage.setItem(
        `practice_${sessionKey}`,
        JSON.stringify({ answers, currentIndex })
      );
    }
  }, [sessionKey, answers, currentIndex]);

  const handleAnswer = useCallback(async (questionId: string, selectedIndex: number, isCorrect: boolean) => {
    const timestamp = Date.now();

    // Update local state immediately
    setAnswers(prev => [...prev, {
      questionId,
      selectedIndex,
      isCorrect,
      timestamp,
    }]);

    // Save to database (fire and forget - don't block UI)
    try {
      await Promise.all([
        fetch('/api/user/answers', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            questionId,
            selectedIndex,
            isCorrect,
            timeSpentMs: null,
          }),
        }),
        fetch('/api/user/review', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ questionId, isCorrect }),
        }),
      ]);
    } catch (error) {
      // Silently fail - local storage backup exists
      console.error('Failed to save answer to server:', error);
    }
  }, []);

  const handleNext = useCallback(() => {
    if (currentIndex < questions.length - 1) {
      setCurrentIndex(prev => prev + 1);
    } else {
      setIsComplete(true);
      // Check if passed and show confetti
      const finalCorrect = answers.filter(a => a.isCorrect).length;
      const percentage = Math.round((finalCorrect / questions.length) * 100);
      if (percentage >= 75) {
        setShowConfetti(true);
        setTimeout(() => setShowConfetti(false), 5000);
      }
    }
  }, [currentIndex, questions.length, answers]);

  const handleRestart = useCallback(() => {
    setCurrentIndex(0);
    setAnswers([]);
    setIsComplete(false);
    setShowConfetti(false);
    // Clear saved session
    if (sessionKey && typeof window !== "undefined") {
      localStorage.removeItem(`practice_${sessionKey}`);
    }
  }, [sessionKey]);

  const correctCount = answers.filter(a => a.isCorrect).length;
  const answeredCount = answers.length;
  const progress = (answeredCount / questions.length) * 100;

  if (isComplete) {
    const finalCorrect = answers.filter(a => a.isCorrect).length;
    const percentage = Math.round((finalCorrect / questions.length) * 100);
    const isPassing = percentage >= 75;

    return (
      <>
        {showConfetti && <Confetti />}
        <ResultsSummary
          answers={answers}
          questions={questions}
          topic={topic}
          onRestart={handleRestart}
          isPassing={isPassing}
          percentage={percentage}
          correctCount={finalCorrect}
        />
      </>
    );
  }

  return (
    <div className="space-y-6">
      {/* Progress Header */}
      <div className="card-clay-static p-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
          <div className="flex items-center gap-2">
            <Target className="h-5 w-5 text-primary" />
            <span className="font-medium">Progress</span>
          </div>
          <div className="flex items-center gap-4 text-sm">
            <span className="flex items-center gap-1.5">
              <CheckCircle2 className="h-4 w-4 text-success-500" />
              <span className="font-medium text-success-600">{correctCount} correct</span>
            </span>
            <span className="text-muted-foreground">
              {answeredCount} of {questions.length} answered
            </span>
          </div>
        </div>
        <div className="h-3 bg-muted rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-primary rounded-full transition-all duration-500 ease-out"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>

      {/* Question */}
      <QuestionCard
        question={questions[currentIndex]}
        questionNumber={currentIndex + 1}
        totalQuestions={questions.length}
        onAnswer={handleAnswer}
        onNext={handleNext}
      />
    </div>
  );
}

interface ResultsSummaryProps {
  answers: AnswerRecord[];
  questions: QuestionData[];
  topic?: string;
  onRestart: () => void;
  isPassing: boolean;
  percentage: number;
  correctCount: number;
}

function ResultsSummary({
  answers,
  questions,
  topic,
  onRestart,
  isPassing,
  percentage,
  correctCount,
}: ResultsSummaryProps) {
  return (
    <div className="card-clay-static w-full max-w-2xl mx-auto p-6 md:p-8">
      {/* Score Circle */}
      <div className="text-center mb-8">
        <div className={`score-circle w-36 h-36 mx-auto ${
          isPassing ? "bg-gradient-success" : "bg-gradient-error"
        }`}>
          <div className="text-center">
            <div className={`text-4xl font-bold font-nunito ${
              isPassing ? "text-success-600" : "text-destructive"
            }`}>
              {percentage}%
            </div>
            <div className="text-sm text-muted-foreground">Score</div>
          </div>
        </div>
      </div>

      {/* Result Message */}
      <div className="text-center mb-8">
        <div className="flex items-center justify-center gap-2 mb-2">
          {isPassing ? (
            <PartyPopper className="h-7 w-7 text-amber-500" />
          ) : (
            <Target className="h-7 w-7 text-primary" />
          )}
          <h2 className="text-2xl md:text-3xl font-bold font-nunito">
            {isPassing ? "Congratulations!" : "Keep Practicing!"}
          </h2>
        </div>
        <p className="text-muted-foreground">
          You got {correctCount} out of {questions.length} questions correct
          {topic && ` in ${topic}`}.
        </p>
        {!isPassing && (
          <Badge variant="outline" className="mt-3">
            You need 75% to pass the Life in the UK test
          </Badge>
        )}
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-4 mb-8">
        <div className="bg-gradient-success p-5 rounded-xl flex items-center gap-4">
          <div className="bg-white/80 p-2.5 rounded-lg">
            <CheckCircle2 className="h-7 w-7 text-success-600" />
          </div>
          <div>
            <div className="text-3xl font-bold font-nunito text-success-600">{correctCount}</div>
            <div className="text-sm text-success-700 font-medium">Correct</div>
          </div>
        </div>
        <div className="bg-gradient-error p-5 rounded-xl flex items-center gap-4">
          <div className="bg-white/80 p-2.5 rounded-lg">
            <XCircle className="h-7 w-7 text-destructive" />
          </div>
          <div>
            <div className="text-3xl font-bold font-nunito text-destructive">{questions.length - correctCount}</div>
            <div className="text-sm text-red-700 font-medium">Incorrect</div>
          </div>
        </div>
      </div>

      {/* Pass/Fail Banner */}
      {isPassing && (
        <div className="bg-gradient-primary text-white p-4 rounded-xl mb-6 flex items-center gap-3">
          <Trophy className="h-6 w-6 text-amber-300" />
          <div>
            <p className="font-semibold">You passed!</p>
            <p className="text-sm text-white/80">Keep practicing to maintain your knowledge.</p>
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="flex flex-col sm:flex-row gap-3">
        <Button onClick={onRestart} variant="outline" className="flex-1 h-12 shadow-clay-sm">
          <RotateCcw className="h-4 w-4 mr-2" />
          Try Again
        </Button>
        <Button asChild className="flex-1 h-12 btn-clay bg-gradient-primary text-white border-0">
          <Link href="/dashboard">
            <Sparkles className="h-4 w-4 mr-2" />
            Dashboard
          </Link>
        </Button>
      </div>
    </div>
  );
}
