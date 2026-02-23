import {
  Landmark,
  Building2,
  Scale,
  MapPin,
  Theater,
  Globe,
  Home,
  Trophy,
  Briefcase,
  BadgeCheck,
  Car,
  TrafficCone,
  Gauge,
  ShieldAlert,
  HardHat,
  Flame,
  Shield,
  Wrench,
  HeartPulse,
  Languages,
  BookOpen,
  Headphones,
  MessageSquare,
  PenTool,
  type LucideIcon,
} from "lucide-react";

/**
 * Multi-exam configuration system.
 * Each exam has its own slug, display info, topics, and test format.
 */

// ─── Exam Type Definition ─────────────────────────────────────────

export interface ExamConfig {
  /** URL slug: e.g. "life-in-uk" */
  slug: string;
  /** Short identifier used in DB */
  id: string;
  /** Display name */
  name: string;
  /** Short tagline */
  tagline: string;
  /** SEO-friendly description */
  description: string;
  /** Country/region */
  region: string;
  /** Icon component */
  icon: LucideIcon;
  /** Card color classes */
  color: string;
  /** Number of questions in official test */
  examQuestions: number;
  /** Time limit in minutes */
  examMinutes: number;
  /** Pass percentage */
  passPercent: number;
  /** Test fee (display string) */
  fee: string;
  /** Whether this exam is currently active (has questions) */
  active: boolean;
  /** "Coming soon" label for inactive exams */
  comingSoon?: boolean;
  /** Topics for this exam */
  topics: ExamTopic[];
}

export interface ExamTopic {
  slug: string;
  name: string;
  dbName: string;
  description: string;
  icon: LucideIcon;
  color: string;
  progressColor: string;
}

// ─── Life in the UK Test ───────────────────────────────────────────

const LIFE_IN_UK_TOPICS: ExamTopic[] = [
  {
    slug: "british-history",
    name: "British History",
    dbName: "British History",
    description: "From Roman times to modern Britain",
    icon: Landmark,
    color: "bg-amber-100 text-amber-600",
    progressColor: "bg-amber-500",
  },
  {
    slug: "uk-government",
    name: "UK Government",
    dbName: "UK Government",
    description: "Parliament, elections, and democracy",
    icon: Building2,
    color: "bg-blue-100 text-blue-600",
    progressColor: "bg-blue-500",
  },
  {
    slug: "laws-rights",
    name: "Laws & Rights",
    dbName: "Laws and Rights",
    description: "Legal system and human rights",
    icon: Scale,
    color: "bg-purple-100 text-purple-600",
    progressColor: "bg-purple-500",
  },
  {
    slug: "geography",
    name: "Geography",
    dbName: "Geography",
    description: "UK regions, cities, and landmarks",
    icon: MapPin,
    color: "bg-green-100 text-green-600",
    progressColor: "bg-green-500",
  },
  {
    slug: "culture-traditions",
    name: "Culture & Traditions",
    dbName: "Culture and Traditions",
    description: "Arts, music, and celebrations",
    icon: Theater,
    color: "bg-pink-100 text-pink-600",
    progressColor: "bg-pink-500",
  },
  {
    slug: "modern-society",
    name: "Modern Society",
    dbName: "A Modern Thriving Society",
    description: "Society, diversity, and values",
    icon: Globe,
    color: "bg-cyan-100 text-cyan-600",
    progressColor: "bg-green-500",
  },
  {
    slug: "becoming-citizen",
    name: "Becoming a Citizen",
    dbName: "Becoming a Citizen",
    description: "Citizenship process and requirements",
    icon: BadgeCheck,
    color: "bg-indigo-100 text-indigo-600",
    progressColor: "bg-rose-500",
  },
  {
    slug: "employment",
    name: "Employment",
    dbName: "Employment",
    description: "Work, careers, and employment rights",
    icon: Briefcase,
    color: "bg-teal-100 text-teal-600",
    progressColor: "bg-indigo-500",
  },
  {
    slug: "everyday-life",
    name: "Everyday Life",
    dbName: "Everyday Life",
    description: "Housing, health, and education",
    icon: Home,
    color: "bg-orange-100 text-orange-600",
    progressColor: "bg-orange-500",
  },
  {
    slug: "sports",
    name: "Sports & Leisure",
    dbName: "Sports",
    description: "Famous sports and achievements",
    icon: Trophy,
    color: "bg-red-100 text-red-600",
    progressColor: "bg-emerald-500",
  },
];

// ─── UK Driving Theory Test ────────────────────────────────────────

const DRIVING_THEORY_TOPICS: ExamTopic[] = [
  {
    slug: "alertness",
    name: "Alertness",
    dbName: "Alertness",
    description: "Observation and anticipation on the road",
    icon: ShieldAlert,
    color: "bg-red-100 text-red-600",
    progressColor: "bg-red-500",
  },
  {
    slug: "attitude",
    name: "Attitude",
    dbName: "Attitude",
    description: "Considerate and safe driving behaviour",
    icon: BadgeCheck,
    color: "bg-blue-100 text-blue-600",
    progressColor: "bg-blue-500",
  },
  {
    slug: "safety-vehicle",
    name: "Safety & Your Vehicle",
    dbName: "Safety and Your Vehicle",
    description: "Vehicle maintenance and safety checks",
    icon: Car,
    color: "bg-green-100 text-green-600",
    progressColor: "bg-green-500",
  },
  {
    slug: "safety-margins",
    name: "Safety Margins",
    dbName: "Safety Margins",
    description: "Stopping distances and weather conditions",
    icon: Gauge,
    color: "bg-amber-100 text-amber-600",
    progressColor: "bg-amber-500",
  },
  {
    slug: "hazard-awareness",
    name: "Hazard Awareness",
    dbName: "Hazard Awareness",
    description: "Identifying and responding to hazards",
    icon: TrafficCone,
    color: "bg-orange-100 text-orange-600",
    progressColor: "bg-orange-500",
  },
  {
    slug: "road-signs",
    name: "Road Signs",
    dbName: "Road Signs",
    description: "Understanding traffic signs and markings",
    icon: TrafficCone,
    color: "bg-purple-100 text-purple-600",
    progressColor: "bg-purple-500",
  },
  {
    slug: "rules-of-the-road",
    name: "Rules of the Road",
    dbName: "Rules of the Road",
    description: "Road rules, lanes, and right of way",
    icon: Scale,
    color: "bg-cyan-100 text-cyan-600",
    progressColor: "bg-cyan-500",
  },
  {
    slug: "road-highway-conditions",
    name: "Road & Highway Conditions",
    dbName: "Road and Highway Conditions",
    description: "Driving in different road conditions",
    icon: MapPin,
    color: "bg-teal-100 text-teal-600",
    progressColor: "bg-teal-500",
  },
  {
    slug: "vulnerable-road-users",
    name: "Vulnerable Road Users",
    dbName: "Vulnerable Road Users",
    description: "Sharing the road safely with all users",
    icon: Globe,
    color: "bg-pink-100 text-pink-600",
    progressColor: "bg-pink-500",
  },
  {
    slug: "vehicle-handling",
    name: "Vehicle Handling",
    dbName: "Vehicle Handling",
    description: "Control and manoeuvres in different situations",
    icon: Car,
    color: "bg-indigo-100 text-indigo-600",
    progressColor: "bg-indigo-500",
  },
];

// ─── CSCS Health, Safety & Environment Test ────────────────────────

const CSCS_TOPICS: ExamTopic[] = [
  {
    slug: "general-safety",
    name: "General Safety",
    dbName: "General Safety",
    description: "Core health and safety principles on site",
    icon: Shield,
    color: "bg-blue-100 text-blue-600",
    progressColor: "bg-blue-500",
  },
  {
    slug: "working-at-height",
    name: "Working at Height",
    dbName: "Working at Height",
    description: "Scaffolding, ladders, and fall prevention",
    icon: HardHat,
    color: "bg-amber-100 text-amber-600",
    progressColor: "bg-amber-500",
  },
  {
    slug: "manual-handling",
    name: "Manual Handling",
    dbName: "Manual Handling",
    description: "Safe lifting, carrying, and moving materials",
    icon: Wrench,
    color: "bg-orange-100 text-orange-600",
    progressColor: "bg-orange-500",
  },
  {
    slug: "fire-prevention",
    name: "Fire Prevention",
    dbName: "Fire Prevention",
    description: "Fire risks, extinguishers, and emergency procedures",
    icon: Flame,
    color: "bg-red-100 text-red-600",
    progressColor: "bg-red-500",
  },
  {
    slug: "hazardous-substances",
    name: "Hazardous Substances",
    dbName: "Hazardous Substances",
    description: "COSHH, asbestos, and chemical safety",
    icon: ShieldAlert,
    color: "bg-purple-100 text-purple-600",
    progressColor: "bg-purple-500",
  },
  {
    slug: "ppe",
    name: "PPE",
    dbName: "Personal Protective Equipment",
    description: "Correct selection and use of protective equipment",
    icon: HardHat,
    color: "bg-green-100 text-green-600",
    progressColor: "bg-green-500",
  },
  {
    slug: "electrical-safety",
    name: "Electrical Safety",
    dbName: "Electrical Safety",
    description: "Working safely with electrical equipment",
    icon: Gauge,
    color: "bg-cyan-100 text-cyan-600",
    progressColor: "bg-cyan-500",
  },
  {
    slug: "first-aid",
    name: "First Aid & Emergencies",
    dbName: "First Aid and Emergencies",
    description: "Emergency procedures and first aid basics",
    icon: HeartPulse,
    color: "bg-pink-100 text-pink-600",
    progressColor: "bg-pink-500",
  },
];

// ─── OET (Occupational English Test) ───────────────────────────────

const OET_TOPICS: ExamTopic[] = [
  {
    slug: "reading-part-a",
    name: "Reading Part A",
    dbName: "Reading Part A",
    description: "Expeditious reading and summary completion",
    icon: BookOpen,
    color: "bg-blue-100 text-blue-600",
    progressColor: "bg-blue-500",
  },
  {
    slug: "reading-part-b",
    name: "Reading Part B",
    dbName: "Reading Part B",
    description: "Careful reading from healthcare texts",
    icon: BookOpen,
    color: "bg-indigo-100 text-indigo-600",
    progressColor: "bg-indigo-500",
  },
  {
    slug: "reading-part-c",
    name: "Reading Part C",
    dbName: "Reading Part C",
    description: "Reading comprehension of detailed texts",
    icon: BookOpen,
    color: "bg-purple-100 text-purple-600",
    progressColor: "bg-purple-500",
  },
  {
    slug: "listening-part-a",
    name: "Listening Part A",
    dbName: "Listening Part A",
    description: "Consultation extracts and note completion",
    icon: Headphones,
    color: "bg-green-100 text-green-600",
    progressColor: "bg-green-500",
  },
  {
    slug: "listening-part-b",
    name: "Listening Part B",
    dbName: "Listening Part B",
    description: "Short workplace extracts",
    icon: Headphones,
    color: "bg-teal-100 text-teal-600",
    progressColor: "bg-teal-500",
  },
  {
    slug: "listening-part-c",
    name: "Listening Part C",
    dbName: "Listening Part C",
    description: "Presentation or interview extracts",
    icon: Headphones,
    color: "bg-cyan-100 text-cyan-600",
    progressColor: "bg-cyan-500",
  },
  {
    slug: "writing",
    name: "Writing",
    dbName: "Writing",
    description: "Referral or discharge letters",
    icon: PenTool,
    color: "bg-amber-100 text-amber-600",
    progressColor: "bg-amber-500",
  },
  {
    slug: "speaking",
    name: "Speaking",
    dbName: "Speaking",
    description: "Role-play consultations with patients",
    icon: MessageSquare,
    color: "bg-pink-100 text-pink-600",
    progressColor: "bg-pink-500",
  },
];

// ─── All Exams Registry ────────────────────────────────────────────

export const EXAMS: ExamConfig[] = [
  {
    slug: "life-in-uk",
    id: "life-in-uk",
    name: "Life in the UK Test",
    tagline: "British citizenship & settlement",
    description:
      "Practice questions for the Life in the UK Test. 500+ questions covering British history, government, laws, and everyday life.",
    region: "United Kingdom",
    icon: Landmark,
    color: "bg-primary/10 text-primary",
    examQuestions: 24,
    examMinutes: 45,
    passPercent: 75,
    fee: "£50",
    active: true,
    topics: LIFE_IN_UK_TOPICS,
  },
  {
    slug: "driving-theory",
    id: "driving-theory",
    name: "UK Driving Theory Test",
    tagline: "Car driving theory & hazard perception",
    description:
      "Practice questions for the UK Driving Theory Test. Master road signs, safety, and the Highway Code.",
    region: "United Kingdom",
    icon: Car,
    color: "bg-green-100 text-green-600",
    examQuestions: 50,
    examMinutes: 57,
    passPercent: 86,
    fee: "£23",
    active: true,
    comingSoon: false,
    topics: DRIVING_THEORY_TOPICS,
  },
  {
    slug: "cscs",
    id: "cscs",
    name: "CSCS Health & Safety Test",
    tagline: "Construction site safety certification",
    description:
      "Practice questions for the CSCS Health, Safety and Environment Test. Essential for construction workers in the UK.",
    region: "United Kingdom",
    icon: HardHat,
    color: "bg-amber-100 text-amber-600",
    examQuestions: 50,
    examMinutes: 45,
    passPercent: 90,
    fee: "£21",
    active: false,
    comingSoon: true,
    topics: CSCS_TOPICS,
  },
  {
    slug: "oet",
    id: "oet",
    name: "OET (Occupational English Test)",
    tagline: "English for healthcare professionals",
    description:
      "Practice for the OET exam. Designed for healthcare professionals seeking to work in English-speaking countries.",
    region: "International",
    icon: Languages,
    color: "bg-purple-100 text-purple-600",
    examQuestions: 42,
    examMinutes: 120,
    passPercent: 70,
    fee: "£587",
    active: false,
    comingSoon: true,
    topics: OET_TOPICS,
  },
];

// ─── Helper Functions ──────────────────────────────────────────────

/** Get active exams only */
export function getActiveExams() {
  return EXAMS.filter((e) => e.active);
}

/** Get all exams including coming soon */
export function getAllExams() {
  return EXAMS;
}

/** Find exam by slug */
export function getExamBySlug(slug: string) {
  return EXAMS.find((e) => e.slug === slug);
}

/** Get the default/primary exam */
export function getDefaultExam() {
  return EXAMS[0];
}

/** Get topics for a specific exam */
export function getExamTopics(examSlug: string) {
  const exam = getExamBySlug(examSlug);
  return exam?.topics ?? [];
}

/** Find topic within an exam by topic slug */
export function getExamTopicBySlug(examSlug: string, topicSlug: string) {
  const topics = getExamTopics(examSlug);
  return topics.find((t) => t.slug === topicSlug);
}

/** Get topic slug → DB name map for an exam */
export function getExamSlugToDb(examSlug: string): Record<string, string> {
  const topics = getExamTopics(examSlug);
  return Object.fromEntries(topics.map((t) => [t.slug, t.dbName]));
}

/** Get DB name → topic slug map for an exam */
export function getExamDbToSlug(examSlug: string): Record<string, string> {
  const topics = getExamTopics(examSlug);
  return Object.fromEntries(topics.map((t) => [t.dbName, t.slug]));
}

/** Get DB name → progress color map for an exam */
export function getExamDbToColor(examSlug: string): Record<string, string> {
  const topics = getExamTopics(examSlug);
  return Object.fromEntries(topics.map((t) => [t.dbName, t.progressColor]));
}

/** Get all topic slugs for an exam (for sitemap) */
export function getExamTopicSlugs(examSlug: string): string[] {
  return getExamTopics(examSlug).map((t) => t.slug);
}
