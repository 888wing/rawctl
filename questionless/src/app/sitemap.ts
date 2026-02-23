import type { MetadataRoute } from "next";
import { getAllExams } from "@/lib/exams";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = "https://question.uk";
  const exams = getAllExams();

  const staticPages: MetadataRoute.Sitemap = [
    { url: baseUrl, lastModified: new Date(), changeFrequency: "weekly", priority: 1.0 },
    { url: `${baseUrl}/exams`, lastModified: new Date(), changeFrequency: "weekly", priority: 0.9 },
    { url: `${baseUrl}/practice`, lastModified: new Date(), changeFrequency: "weekly", priority: 0.9 },
    { url: `${baseUrl}/pricing`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.7 },
    { url: `${baseUrl}/about`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.5 },
    { url: `${baseUrl}/privacy`, lastModified: new Date(), changeFrequency: "yearly", priority: 0.3 },
    { url: `${baseUrl}/terms`, lastModified: new Date(), changeFrequency: "yearly", priority: 0.3 },
  ];

  // Exam detail pages
  const examPages: MetadataRoute.Sitemap = exams.map((exam) => ({
    url: `${baseUrl}/exams/${exam.slug}`,
    lastModified: new Date(),
    changeFrequency: "weekly" as const,
    priority: 0.8,
  }));

  // Topic practice pages for active exams
  const topicPages: MetadataRoute.Sitemap = exams
    .filter((exam) => exam.active)
    .flatMap((exam) =>
      exam.topics.map((topic) => ({
        url:
          exam.slug === "life-in-uk"
            ? `${baseUrl}/practice/${topic.slug}`
            : `${baseUrl}/exams/${exam.slug}/practice/${topic.slug}`,
        lastModified: new Date(),
        changeFrequency: "weekly" as const,
        priority: 0.7,
      }))
    );

  return [...staticPages, ...examPages, ...topicPages];
}
