import { NextResponse } from "next/server";

export const runtime = 'edge';

const GEMINI_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

interface GeneratedQuestion {
  question: string;
  options: string[];
  correct_index: number;
  difficulty: "easy" | "medium" | "hard";
  explanation: string;
  handbook_ref: string;
  topic: string;
}

export async function POST(request: Request) {
  try {
    const { content, topic, count = 5 } = await request.json() as { content?: string; topic?: string; count?: number };

    if (!content || !topic) {
      return NextResponse.json(
        { error: "Content and topic are required" },
        { status: 400 }
      );
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return NextResponse.json(
        { error: "GEMINI_API_KEY not configured" },
        { status: 500 }
      );
    }

    const prompt = `You are a Life in the UK Test question generation expert. Generate practice questions based on the following official handbook content.

【Chapter Content】
${content}

【Topic】
${topic}

【Requirements】
- Generate ${count} multiple choice questions
- Each question has 4 options, only 1 correct answer
- Difficulty distribution: 40% easy, 40% medium, 20% hard
- Must be based on provided content, no fabricated facts
- Provide detailed explanation with original text reference
- Questions should test factual knowledge that appears in the actual Life in UK test
- Focus on dates, names, places, and key facts

【Output Format (JSON only, no markdown)】
{
  "questions": [
    {
      "question": "Question text in English",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "difficulty": "easy|medium|hard",
      "explanation": "Explanation text referencing the handbook",
      "handbook_ref": "Direct quote from the content",
      "topic": "${topic}"
    }
  ]
}

IMPORTANT: Return ONLY valid JSON, no markdown code blocks or additional text.`;

    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 4096,
        },
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("Gemini API error:", error);
      return NextResponse.json(
        { error: "Failed to generate questions" },
        { status: 500 }
      );
    }

    const data = await response.json() as { candidates?: { content?: { parts?: { text?: string }[] } }[]; usageMetadata?: { totalTokenCount?: number } };
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      return NextResponse.json(
        { error: "No response from Gemini" },
        { status: 500 }
      );
    }

    // Clean up potential markdown code blocks
    const cleanedText = text
      .replace(/```json\n?/g, "")
      .replace(/```\n?/g, "")
      .trim();

    const result = JSON.parse(cleanedText);

    return NextResponse.json({
      questions: result.questions,
      tokens_used: data.usageMetadata?.totalTokenCount,
    });
  } catch (error) {
    console.error("Question generation error:", error);
    return NextResponse.json(
      { error: "Failed to generate questions" },
      { status: 500 }
    );
  }
}
