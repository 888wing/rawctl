'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { QuestionCard, Confetti } from '@/components/question';
import type { QuestionData } from '@/components/question/QuestionCard';

export const runtime = 'edge';

interface ExamState {
  examId: string;
  questions: QuestionData[];
  currentIndex: number;
  answers: { questionId: string; selectedIndex: number }[];
  timeRemaining: number;
  completed: boolean;
  score: number | null;
  passed: boolean | null;
}

export default function MockExamStartPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [examState, setExamState] = useState<ExamState | null>(null);
  const [showResults, setShowResults] = useState(false);

  // Submit exam function
  const submitExam = useCallback(async (answers: { questionId: string; selectedIndex: number }[], examId: string) => {
    try {
      const res = await fetch(`/api/mock-exam/${examId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ answers, completed: true }),
      });

      if (!res.ok) throw new Error('Failed to submit exam');
      const data = await res.json() as { score?: number; passed?: boolean };

      setExamState(prev => prev ? {
        ...prev,
        completed: true,
        score: data.score ?? 0,
        passed: data.passed ?? false,
      } : prev);
      setShowResults(true);
    } catch {
      setError('Failed to submit exam');
    }
  }, []);

  // Initialize exam
  useEffect(() => {
    async function startExam() {
      try {
        const res = await fetch('/api/mock-exam', { method: 'POST' });
        if (!res.ok) throw new Error('Failed to start exam');
        const data = await res.json() as { examId: string; questions: QuestionData[]; timeLimit: number };

        setExamState({
          examId: data.examId,
          questions: data.questions,
          currentIndex: 0,
          answers: [],
          timeRemaining: data.timeLimit,
          completed: false,
          score: null,
          passed: null,
        });
        setLoading(false);
      } catch {
        setError('Failed to start exam. Please try again.');
        setLoading(false);
      }
    }
    startExam();
  }, []);

  // Timer
  useEffect(() => {
    if (!examState || examState.completed) return;

    const timer = setInterval(() => {
      setExamState(prev => {
        if (!prev) return prev;
        const newTime = prev.timeRemaining - 1;
        if (newTime <= 0) {
          // Auto-submit
          submitExam(prev.answers, prev.examId);
          return { ...prev, timeRemaining: 0, completed: true };
        }
        return { ...prev, timeRemaining: newTime };
      });
    }, 1000);

    return () => clearInterval(timer);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [examState?.completed, examState?.examId, submitExam]);

  const handleAnswer = useCallback((_questionId: string, selectedIndex: number, _isCorrect: boolean) => {
    if (!examState || examState.completed) return;

    const question = examState.questions[examState.currentIndex];
    const newAnswers = [
      ...examState.answers,
      { questionId: question.id, selectedIndex },
    ];

    // Move to next question or finish
    if (examState.currentIndex < examState.questions.length - 1) {
      setExamState(prev => prev ? {
        ...prev,
        currentIndex: prev.currentIndex + 1,
        answers: newAnswers,
      } : prev);
    } else {
      // Last question - submit
      submitExam(newAnswers, examState.examId);
    }
  }, [examState, submitExam]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-hero p-4 flex items-center justify-center">
        <div className="card-clay p-8 text-center">
          <div className="animate-spin w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full mx-auto mb-4" />
          <p className="text-slate-600">Preparing your exam...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-hero p-4 flex items-center justify-center">
        <div className="card-clay p-8 text-center">
          <p className="text-red-600 mb-4">{error}</p>
          <button onClick={() => router.push('/mock-exam')} className="btn-clay px-6 py-3">
            Back to Mock Exam
          </button>
        </div>
      </div>
    );
  }

  if (showResults && examState) {
    return (
      <div className="min-h-screen bg-gradient-hero p-4">
        {examState.passed && <Confetti />}
        <div className="max-w-2xl mx-auto">
          <div className="card-clay p-8 text-center">
            <h1 className="text-3xl font-nunito font-bold mb-4">
              {examState.passed ? '🎉 Congratulations!' : '📚 Keep Practicing'}
            </h1>
            <div className={`text-6xl font-bold mb-4 ${examState.passed ? 'text-green-600' : 'text-red-600'}`}>
              {examState.score}%
            </div>
            <p className="text-slate-600 mb-6">
              {examState.passed
                ? 'You passed! Great job preparing for your Life in the UK test.'
                : 'You need 75% to pass. Review the topics and try again.'}
            </p>
            <div className="flex gap-4 justify-center">
              <button onClick={() => router.push('/dashboard')} className="btn-clay px-6 py-3">
                Dashboard
              </button>
              <button onClick={() => window.location.reload()} className="btn-clay bg-gradient-primary text-white px-6 py-3">
                Try Again
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!examState) return null;

  const currentQuestion = examState.questions[examState.currentIndex];
  const isLowTime = examState.timeRemaining <= 300; // 5 minutes

  return (
    <div className="min-h-screen bg-gradient-hero p-4">
      <div className="max-w-2xl mx-auto">
        {/* Timer and Progress Bar */}
        <div className="card-clay p-4 mb-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm text-slate-600">
              Question {examState.currentIndex + 1} of {examState.questions.length}
            </span>
            <span className={`font-mono font-bold ${isLowTime ? 'text-red-600 animate-pulse' : 'text-slate-800'}`}>
              ⏱️ {formatTime(examState.timeRemaining)}
            </span>
          </div>
          <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-primary transition-all duration-300"
              style={{ width: `${((examState.currentIndex) / examState.questions.length) * 100}%` }}
            />
          </div>
        </div>

        {/* Question */}
        <QuestionCard
          question={currentQuestion}
          questionNumber={examState.currentIndex + 1}
          totalQuestions={examState.questions.length}
          onAnswer={handleAnswer}
          onNext={() => {}}
        />
      </div>
    </div>
  );
}
