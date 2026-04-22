/**
 * Gemini 3 Flash Integration for Question Generation
 */

type GeminiResponse = { candidates?: { content?: { parts?: { text?: string }[] } }[]; usageMetadata?: { totalTokenCount?: number } };

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

export interface GeneratedQuestion {
  question: string;
  options: string[];
  correct_index: number;
  difficulty: 'easy' | 'medium' | 'hard';
  explanation: string;
  handbook_ref: string;
  confidence: number;
}

export interface GenerationResult {
  questions: GeneratedQuestion[];
  tokens_used?: number;
}

const QUESTION_GENERATION_PROMPT = `You are a Life in the UK Test question generation expert. Generate practice questions based on the following official handbook content.

【Chapter Content】
{chapter_content}

【Requirements】
- Generate {count} multiple choice questions
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
      "confidence": 0.95
    }
  ]
}

IMPORTANT: Return ONLY valid JSON, no markdown code blocks or additional text.`;

/**
 * Generate questions using Gemini 3 Flash
 */
export async function generateQuestions(
  chapterContent: string,
  count: number = 5,
  apiKey?: string
): Promise<GenerationResult> {
  const key = apiKey || process.env.GEMINI_API_KEY;
  if (!key) {
    throw new Error('GEMINI_API_KEY is not set');
  }

  const prompt = QUESTION_GENERATION_PROMPT
    .replace('{chapter_content}', chapterContent)
    .replace('{count}', count.toString());

  const response = await fetch(`${GEMINI_API_URL}?key=${key}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
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
    throw new Error(`Gemini API error: ${error}`);
  }

  const data = await response.json() as GeminiResponse;
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    throw new Error('No response from Gemini');
  }

  // Parse JSON response
  try {
    // Clean up potential markdown code blocks
    const cleanedText = text
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();

    const result = JSON.parse(cleanedText);
    return {
      questions: result.questions,
      tokens_used: data.usageMetadata?.totalTokenCount,
    };
  } catch (e) {
    console.error('Failed to parse Gemini response:', text);
    throw new Error('Failed to parse question generation response');
  }
}

/**
 * Verify a generated question against the handbook content
 */
export async function verifyQuestion(
  question: GeneratedQuestion,
  handbookContent: string,
  apiKey?: string
): Promise<{ valid: boolean; reason?: string }> {
  const key = apiKey || process.env.GEMINI_API_KEY;
  if (!key) {
    throw new Error('GEMINI_API_KEY is not set');
  }

  const verificationPrompt = `You are a fact-checker for Life in the UK Test questions.

【Question to Verify】
Question: ${question.question}
Correct Answer: ${question.options[question.correct_index]}
Explanation: ${question.explanation}

【Handbook Content】
${handbookContent}

【Task】
Verify if:
1. The question is factually accurate based on the handbook
2. The correct answer is indeed correct
3. The explanation is accurate

Return JSON only:
{
  "valid": true/false,
  "reason": "Explanation if invalid"
}`;

  const response = await fetch(`${GEMINI_API_URL}?key=${key}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [{ text: verificationPrompt }],
        },
      ],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 256,
      },
    }),
  });

  if (!response.ok) {
    throw new Error('Verification API error');
  }

  const data = await response.json() as GeminiResponse;
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    return { valid: false, reason: 'No response from Gemini' };
  }

  try {
    const cleanedText = text
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();
    return JSON.parse(cleanedText);
  } catch {
    return { valid: false, reason: 'Failed to verify' };
  }
}

/**
 * Batch generate and verify questions
 */
export async function generateAndVerifyQuestions(
  chapterContent: string,
  count: number = 5,
  apiKey?: string
): Promise<GeneratedQuestion[]> {
  // Generate questions
  const generated = await generateQuestions(chapterContent, count, apiKey);

  // Verify each question
  const verified: GeneratedQuestion[] = [];
  for (const question of generated.questions) {
    const verification = await verifyQuestion(question, chapterContent, apiKey);
    if (verification.valid) {
      verified.push(question);
    } else {
      console.log(`Question rejected: ${verification.reason}`);
    }
  }

  return verified;
}
