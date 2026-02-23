"use client";

import { useState, useEffect, useCallback } from "react";
import { Card, CardContent, CardFooter, CardHeader } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { CheckCircle2, XCircle, ChevronRight, BookOpen, Lightbulb, Keyboard } from "lucide-react";
import { cn } from "@/lib/utils";

export interface QuestionData {
  id: string;
  question: string;
  options: string[];
  correctIndex: number;
  explanation?: string;
  topic: string;
  difficulty: "easy" | "medium" | "hard";
  handbookRef?: string;
}

interface QuestionCardProps {
  question: QuestionData;
  questionNumber: number;
  totalQuestions: number;
  onAnswer: (questionId: string, selectedIndex: number, isCorrect: boolean) => void;
  onNext: () => void;
}

const difficultyConfig = {
  easy: { label: "Easy", class: "badge-easy" },
  medium: { label: "Medium", class: "badge-medium" },
  hard: { label: "Hard", class: "badge-hard" },
};

export function QuestionCard({
  question,
  questionNumber,
  totalQuestions,
  onAnswer,
  onNext,
}: QuestionCardProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [hasAnswered, setHasAnswered] = useState(false);
  const [animationClass, setAnimationClass] = useState("");

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Prevent action if user is typing in an input
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }

      // Option selection with 1-4 or A-D
      const keyMap: Record<string, number> = {
        '1': 0, '2': 1, '3': 2, '4': 3,
        'a': 0, 'b': 1, 'c': 2, 'd': 3,
        'A': 0, 'B': 1, 'C': 2, 'D': 3,
      };

      if (!hasAnswered && keyMap[e.key] !== undefined && keyMap[e.key] < question.options.length) {
        e.preventDefault();
        handleOptionClick(keyMap[e.key]);
      }

      // Next question with Enter or Space
      if (hasAnswered && (e.key === 'Enter' || e.key === ' ')) {
        e.preventDefault();
        handleNext();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasAnswered, question.options.length]);

  const handleOptionClick = useCallback((index: number) => {
    if (hasAnswered) return;

    setSelectedIndex(index);
    setHasAnswered(true);
    const isCorrect = index === question.correctIndex;

    // Trigger animation
    setAnimationClass(isCorrect ? "animate-celebrate" : "animate-shake");

    onAnswer(question.id, index, isCorrect);

    // Clear animation class after animation completes
    setTimeout(() => setAnimationClass(""), 500);
  }, [hasAnswered, question.correctIndex, question.id, onAnswer]);

  const handleNext = useCallback(() => {
    setSelectedIndex(null);
    setHasAnswered(false);
    setAnimationClass("");
    onNext();
  }, [onNext]);

  const isCorrectAnswer = selectedIndex !== null && selectedIndex === question.correctIndex;

  return (
    <div className={cn("card-clay-static w-full max-w-2xl mx-auto overflow-hidden", animationClass)}>
      {/* Header */}
      <div className="p-5 pb-0">
        <div className="flex items-center justify-between mb-4">
          <span className="text-sm text-muted-foreground font-medium">
            Question {questionNumber} of {totalQuestions}
          </span>
          <div className="flex gap-2">
            <Badge variant="outline" className="text-xs">{question.topic}</Badge>
            <Badge className={cn("text-xs capitalize border", difficultyConfig[question.difficulty].class)}>
              {difficultyConfig[question.difficulty].label}
            </Badge>
          </div>
        </div>

        {/* Question */}
        <h2 className="text-lg md:text-xl font-semibold leading-relaxed mb-6">
          {question.question}
        </h2>
      </div>

      {/* Options */}
      <div className="px-5 space-y-3">
        {question.options.map((option, index) => (
          <OptionButton
            key={index}
            option={option}
            index={index}
            isSelected={selectedIndex === index}
            isCorrect={index === question.correctIndex}
            hasAnswered={hasAnswered}
            onClick={() => handleOptionClick(index)}
          />
        ))}
      </div>

      {/* Explanation */}
      {hasAnswered && question.explanation && (
        <div className="mx-5 mt-6 p-5 bg-muted/50 rounded-xl border animate-scale-in">
          <div className="flex items-center gap-2 font-semibold mb-3">
            <Lightbulb className="h-5 w-5 text-amber-500" />
            <span>Explanation</span>
          </div>
          <p className="text-muted-foreground leading-relaxed">
            {question.explanation}
          </p>
          {question.handbookRef && (
            <p className="text-sm text-muted-foreground mt-3 flex items-center gap-1.5">
              <BookOpen className="h-4 w-4" />
              <span className="italic">Reference: {question.handbookRef}</span>
            </p>
          )}
        </div>
      )}

      {/* Footer */}
      <div className="p-5 pt-6">
        {hasAnswered ? (
          <Button onClick={handleNext} className="w-full btn-clay bg-gradient-primary text-white border-0 h-12">
            {questionNumber < totalQuestions ? (
              <>
                Next Question
                <ChevronRight className="h-5 w-5 ml-2" />
              </>
            ) : (
              <>
                View Results
                <ChevronRight className="h-5 w-5 ml-2" />
              </>
            )}
          </Button>
        ) : (
          <div className="flex items-center justify-center gap-2 text-sm text-muted-foreground">
            <Keyboard className="h-4 w-4" />
            <span>Press <kbd className="px-1.5 py-0.5 bg-muted rounded text-xs font-mono">A-D</kbd> or <kbd className="px-1.5 py-0.5 bg-muted rounded text-xs font-mono">1-4</kbd> to select</span>
          </div>
        )}
      </div>
    </div>
  );
}

interface OptionButtonProps {
  option: string;
  index: number;
  isSelected: boolean;
  isCorrect: boolean;
  hasAnswered: boolean;
  onClick: () => void;
}

function OptionButton({
  option,
  index,
  isSelected,
  isCorrect,
  hasAnswered,
  onClick,
}: OptionButtonProps) {
  const letter = String.fromCharCode(65 + index); // A, B, C, D

  let stateClasses = "border-border/50 hover:border-primary/50 hover:bg-primary/5 shadow-clay-sm";

  if (hasAnswered) {
    if (isCorrect) {
      stateClasses = "option-btn-correct";
    } else if (isSelected && !isCorrect) {
      stateClasses = "option-btn-incorrect";
    } else {
      stateClasses = "option-btn-disabled border-border/30";
    }
  } else if (isSelected) {
    stateClasses = "border-primary bg-primary/5 shadow-clay";
  }

  return (
    <button
      onClick={onClick}
      disabled={hasAnswered}
      aria-label={`Option ${letter}: ${option}`}
      className={cn(
        "w-full flex items-center gap-4 p-4 rounded-xl border-2 text-left transition-all duration-200",
        stateClasses,
        !hasAnswered && "cursor-pointer active:scale-[0.98]"
      )}
    >
      <span className={cn(
        "flex-shrink-0 w-10 h-10 rounded-xl flex items-center justify-center text-sm font-bold transition-all",
        hasAnswered && isCorrect
          ? "bg-success-500 text-white"
          : hasAnswered && isSelected && !isCorrect
          ? "bg-destructive text-white"
          : "bg-muted"
      )}>
        {hasAnswered && isCorrect ? (
          <CheckCircle2 className="h-5 w-5" />
        ) : hasAnswered && isSelected && !isCorrect ? (
          <XCircle className="h-5 w-5" />
        ) : (
          letter
        )}
      </span>
      <span className="flex-1 font-medium">{option}</span>
    </button>
  );
}
