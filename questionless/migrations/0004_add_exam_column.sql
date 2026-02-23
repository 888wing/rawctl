-- Add exam column to questions table for multi-exam support
ALTER TABLE questions ADD COLUMN exam TEXT NOT NULL DEFAULT 'life-in-uk';

-- Add exam column to mock_exams table
ALTER TABLE mock_exams ADD COLUMN exam TEXT NOT NULL DEFAULT 'life-in-uk';

-- Create index for efficient exam-based queries
CREATE INDEX IF NOT EXISTS idx_questions_exam ON questions(exam);
CREATE INDEX IF NOT EXISTS idx_questions_exam_topic ON questions(exam, topic);
CREATE INDEX IF NOT EXISTS idx_mock_exams_exam ON mock_exams(exam);
