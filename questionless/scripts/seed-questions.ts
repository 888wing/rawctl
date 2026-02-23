/**
 * Seed script to generate sample questions using Gemini and store in D1
 * Run with: npx tsx scripts/seed-questions.ts
 */

// Load environment variables from .env.local
import * as fs from 'fs';
import * as path from 'path';

const envPath = path.join(process.cwd(), '.env.local');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      const value = valueParts.join('=');
      if (key && value) {
        process.env[key] = value;
      }
    }
  });
}

const GEMINI_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

// All topics matching the API route topicMap with comprehensive content
const TOPICS = [
  {
    topic: "British History",
    content: `
      Stone Age hunters crossed from Europe via land bridge to Britain.
      Stonehenge built around 3000 years ago - mysterious ancient monument.
      Bronze Age people from Iberian Peninsula buried dead in round barrows.
      Iron Age Celts arrived, used iron for tools and weapons.
      Romans invaded under Emperor Claudius in AD 43.
      Hadrian's Wall built to defend northern frontier.
      Romans left Britain in AD 410.
      Anglo-Saxons arrived from Germany and Denmark.
      Vikings from Scandinavia raided and settled in Britain.
      Norman conquest 1066 - William the Conqueror defeated Harold at Battle of Hastings.
      Domesday Book compiled 1086 to record property ownership.
      Magna Carta signed 1215 - limited king's power.
      Black Death 1348 killed one third of population.
      Hundred Years' War with France 1337-1453.
      Wars of the Roses - Lancaster vs York 1455-1485.
      Henry VII won Battle of Bosworth 1485, started Tudor dynasty.
      Henry VIII broke from Rome, established Church of England.
      Elizabeth I defeated Spanish Armada 1588.
      James I united crowns of England and Scotland 1603.
      English Civil War 1642-1651 - Parliament vs King.
      Charles I executed 1649.
      Oliver Cromwell ruled as Lord Protector.
      Restoration 1660 - Charles II returned.
      Glorious Revolution 1688 - William and Mary.
      Act of Union 1707 - England and Scotland became Great Britain.
      Georgian era - Hanoverian kings.
      Industrial Revolution transformed Britain.
      Victorian era 1837-1901 - British Empire at height.
      World War I 1914-1918.
      World War II 1939-1945.
      NHS established 1948.
      Britain joined EEC 1973.
    `,
  },
  {
    topic: "A Modern Thriving Society",
    content: `
      UK is a diverse multicultural society.
      Commonwealth nations share historical ties with Britain.
      Migration has shaped modern Britain.
      Empire Windrush 1948 brought Caribbean workers.
      Post-war immigration from India, Pakistan, Bangladesh.
      EU expansion brought Eastern European workers.
      UK population over 67 million.
      England most populous nation in UK.
      London is largest city with 9 million people.
      Edinburgh capital of Scotland.
      Cardiff capital of Wales.
      Belfast capital of Northern Ireland.
      Official languages: English, Welsh (in Wales), Scottish Gaelic.
      Christianity is main religion but many faiths practiced.
      Freedom of religion guaranteed.
      Festivals: Christmas, Easter, Eid, Diwali, Hanukkah, Vaisakhi.
      St George's Day 23 April - England.
      St Andrew's Day 30 November - Scotland.
      St David's Day 1 March - Wales.
      St Patrick's Day 17 March - Northern Ireland.
      Remembrance Day 11 November.
      Guy Fawkes Night 5 November.
      Hogmanay - Scottish New Year celebration.
    `,
  },
  {
    topic: "UK Government",
    content: `
      UK is a constitutional monarchy and parliamentary democracy.
      The monarch is Head of State - currently King Charles III.
      Parliament is supreme legislative authority.
      Parliament has two Houses: Commons and Lords.
      House of Commons has 650 elected MPs.
      House of Lords has appointed and hereditary peers.
      Prime Minister leads the government.
      Prime Minister appoints Cabinet ministers.
      General elections held at least every 5 years.
      First Past the Post voting system.
      All citizens 18+ can vote.
      Electoral register - must register to vote.
      Political parties: Conservative, Labour, Liberal Democrats, SNP, others.
      Government departments run by ministers.
      Civil servants implement policies impartially.
      Devolved governments in Scotland, Wales, Northern Ireland.
      Scottish Parliament in Edinburgh.
      Welsh Senedd in Cardiff.
      Northern Ireland Assembly at Stormont.
      Local councils provide local services.
      Councillors elected locally.
      Mayor of London elected separately.
      Foreign policy remains with Westminster.
      Defence is UK-wide responsibility.
    `,
  },
  {
    topic: "Laws and Rights",
    content: `
      Rule of law fundamental to UK society.
      Everyone equal before the law.
      Laws made by Parliament.
      Courts independent from government.
      Judges interpret and apply the law.
      Criminal law - offences against society.
      Civil law - disputes between individuals.
      Innocent until proven guilty.
      Right to a fair trial.
      Police maintain law and order.
      Police forces locally organized.
      Metropolitan Police in London.
      Police Scotland, PSNI.
      Human Rights Act 1998.
      Right to life, liberty, fair trial.
      Freedom of expression and assembly.
      Protection from discrimination.
      Equality Act 2010 protects from discrimination.
      Protected characteristics: age, disability, gender, race, religion, etc.
      Employment rights - minimum wage, working hours.
      Consumer rights - Sale of Goods Act.
      Driving laws - must have licence and insurance.
      Drink driving limit strictly enforced.
      Drugs classified A, B, C by danger.
      Age restrictions: voting 18, alcohol 18, driving 17.
      Marriage legal at 18 (16 with consent in some areas).
      Jury service - citizens can be called.
    `,
  },
  {
    topic: "Geography",
    content: `
      UK comprises England, Scotland, Wales, Northern Ireland.
      Great Britain is the island containing England, Scotland, Wales.
      British Isles includes Ireland.
      England largest country in UK.
      Scotland in the north, Edinburgh capital.
      Wales in the west, Cardiff capital.
      Northern Ireland shares island with Republic of Ireland.
      Channel Islands and Isle of Man are Crown Dependencies.
      Ben Nevis highest mountain in UK (Scotland).
      Snowdon highest in Wales.
      Scafell Pike highest in England.
      River Thames flows through London.
      River Severn longest river in UK.
      Lake District national park.
      Scottish Highlands.
      Giant's Causeway in Northern Ireland.
      White Cliffs of Dover.
      UK has temperate maritime climate.
      Weather often mild and wet.
      Coastline over 19,000 miles.
      Major cities: London, Birmingham, Manchester, Glasgow, Liverpool.
      Motorways link major cities.
      Railways extensive network.
      Heathrow busiest airport.
    `,
  },
  {
    topic: "Culture and Traditions",
    content: `
      UK has rich cultural heritage.
      William Shakespeare greatest English writer.
      Shakespeare wrote Hamlet, Macbeth, Romeo and Juliet.
      Globe Theatre in London reconstructed.
      Charles Dickens wrote Oliver Twist, Great Expectations.
      Jane Austen wrote Pride and Prejudice.
      The Brontë sisters - Charlotte, Emily, Anne.
      Poets: Wordsworth, Keats, Byron, Burns, Thomas.
      Sir Arthur Conan Doyle created Sherlock Holmes.
      Agatha Christie - crime writer.
      JK Rowling wrote Harry Potter.
      British Museum, National Gallery, Tate Modern.
      Edinburgh Festival largest arts festival.
      National Trust preserves historic properties.
      English Heritage manages historic sites.
      BBC - British Broadcasting Corporation founded 1922.
      The Beatles from Liverpool.
      Rolling Stones, Queen, Elton John.
      British films and actors.
      Fish and chips traditional dish.
      Roast beef and Yorkshire pudding.
      Haggis Scottish dish.
      Afternoon tea tradition.
      Pubs - public houses social gathering.
      Pantomimes at Christmas.
    `,
  },
  {
    topic: "Everyday Life",
    content: `
      UK uses pounds sterling (£).
      Banks open Monday-Friday.
      Shops typically open 9am-5pm, longer in cities.
      NHS provides free healthcare.
      Register with GP (General Practitioner).
      Call 999 for emergencies.
      Call 111 for non-emergency health advice.
      Education compulsory ages 5-16 (18 in England).
      State schools free.
      National Curriculum followed.
      GCSEs at 16, A-levels at 18.
      Universities charge tuition fees.
      Council Tax pays for local services.
      National Insurance contributions.
      Income Tax collected by HMRC.
      Driving on left side of road.
      Speed limits: 30mph towns, 60mph single roads, 70mph motorways.
      MOT test required annually for cars over 3 years.
      TV licence required for live TV.
      Recycling widely practiced.
      Imperial and metric measurements both used.
      Queuing is expected social behaviour.
      Tipping in restaurants 10-15%.
      Smoking banned in enclosed public spaces.
    `,
  },
  {
    topic: "Employment",
    content: `
      Right to work depends on immigration status.
      National Insurance number needed for work.
      Minimum wage set by government.
      Different rates for different ages.
      Apprenticeships combine work and study.
      Employment contract outlines terms.
      Working Time Regulations limit hours.
      48 hour weekly limit (can opt out).
      Paid holiday entitlement.
      Statutory sick pay.
      Maternity and paternity leave.
      Equal pay for equal work.
      Discrimination at work illegal.
      Trade unions represent workers.
      ACAS helps resolve workplace disputes.
      Jobcentre Plus helps find work.
      Universal Credit - benefits system.
      Self-employment - register with HMRC.
      Health and safety regulations.
      Redundancy rights if job lost.
      Unfair dismissal protection.
      Whistleblowing protection.
      Zero hours contracts exist.
      Agency workers have rights.
    `,
  },
  {
    topic: "Becoming a Citizen",
    content: `
      British citizenship by birth, descent, or naturalisation.
      Naturalisation requires 5 years residence (3 if married to citizen).
      Must be of good character.
      Life in the UK Test required.
      English language requirement - B1 level.
      Application to Home Office.
      Citizenship ceremony required.
      Oath or affirmation of allegiance.
      Pledge to respect rights and freedoms.
      British passport can be applied for after ceremony.
      Indefinite Leave to Remain is permanent residence.
      ILR required before citizenship application.
      Citizens can vote in all elections.
      Citizens can stand for public office.
      Citizens can work without restrictions.
      British Overseas Territories citizenship.
      Commonwealth citizens have some rights.
      Dual nationality allowed.
      Can lose citizenship in certain circumstances.
      Rights come with responsibilities.
      Respect laws and values.
      Participate in community.
    `,
  },
  {
    topic: "Sports",
    content: `
      Football most popular sport.
      Premier League - top English football league.
      FA Cup oldest football competition.
      England, Scotland, Wales, NI have separate teams.
      Rugby Union and Rugby League popular.
      Six Nations rugby championship.
      Cricket - England and Wales Cricket Board.
      The Ashes - England vs Australia.
      Test cricket invented in England.
      Wimbledon - oldest tennis tournament.
      Open Championship - golf major at British courses.
      St Andrews - home of golf.
      Horse racing - Epsom Derby, Grand National, Royal Ascot.
      Formula 1 British Grand Prix at Silverstone.
      Olympics held in London 1908, 1948, 2012.
      Commonwealth Games.
      Snooker originated in India, popular in UK.
      Boxing has strong British tradition.
      British athletes: Mo Farah, Jessica Ennis-Hill, Andy Murray.
      Football clubs: Manchester United, Liverpool, Arsenal, Chelsea.
      National stadiums: Wembley, Twickenham, Murrayfield.
      Sport promotes health and community.
      Volunteering in sport encouraged.
      Paralympic Games - UK strong competitor.
    `,
  },
];

interface GeneratedQuestion {
  question: string;
  options: string[];
  correct_index: number;
  difficulty: string;
  explanation: string;
  handbook_ref: string;
  topic: string;
}

async function generateQuestions(
  topic: string,
  content: string,
  count: number = 5
): Promise<GeneratedQuestion[]> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not set");
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

  console.log(`Generating ${count} questions for topic: ${topic}...`);

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
    throw new Error(`Gemini API error: ${error}`);
  }

  const data = await response.json() as { candidates?: { content?: { parts?: { text?: string }[] } }[] };
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    throw new Error("No response from Gemini");
  }

  const cleanedText = text
    .replace(/```json\n?/g, "")
    .replace(/```\n?/g, "")
    .trim();

  const result = JSON.parse(cleanedText);
  console.log(`✓ Generated ${result.questions.length} questions for ${topic}`);
  return result.questions;
}

async function main() {
  console.log("🚀 Starting question generation...\n");

  const allQuestions: GeneratedQuestion[] = [];

  for (const { topic, content } of TOPICS) {
    try {
      // Generate 20 questions per topic to reach 200+ total
      const questions = await generateQuestions(topic, content, 20);
      allQuestions.push(...questions);
      // Add delay to avoid rate limiting
      await new Promise((resolve) => setTimeout(resolve, 2000));
    } catch (error) {
      console.error(`❌ Failed to generate questions for ${topic}:`, error);
    }
  }

  console.log(`\n📊 Total questions generated: ${allQuestions.length}`);

  // Output SQL INSERT statements for D1
  console.log("\n📝 SQL INSERT statements for D1:\n");

  const insertStatements = allQuestions.map((q, idx) => {
    const escapedQuestion = q.question.replace(/'/g, "''");
    const escapedOptions = JSON.stringify(q.options).replace(/'/g, "''");
    const escapedExplanation = (q.explanation || "").replace(/'/g, "''");
    const escapedHandbookRef = (q.handbook_ref || "").replace(/'/g, "''");
    const escapedTopic = q.topic.replace(/'/g, "''");
    const questionId = `q_${Date.now()}_${idx}_${Math.random().toString(36).substring(7)}`;

    // Match schema column names: question, options, correct_index, difficulty, topic, explanation, handbook_ref, source, verified
    return `INSERT INTO questions (id, question, options, correct_index, difficulty, topic, explanation, handbook_ref, source, verified)
VALUES ('${questionId}', '${escapedQuestion}', '${escapedOptions}', ${q.correct_index}, '${q.difficulty}', '${escapedTopic}', '${escapedExplanation}', '${escapedHandbookRef}', 'ai_generated', 1);`;
  });

  // Write to file
  const fs = await import("fs");
  const path = await import("path");

  // Ensure directories exist
  const migrationsDir = "migrations";
  const dataDir = "data";
  if (!fs.existsSync(migrationsDir)) fs.mkdirSync(migrationsDir, { recursive: true });
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

  const sqlContent = insertStatements.join("\n\n");
  fs.writeFileSync(path.join(migrationsDir, "0002_seed_questions.sql"), sqlContent);
  console.log(`✅ SQL file written to ${migrationsDir}/0002_seed_questions.sql`);

  // Also write JSON for reference
  fs.writeFileSync(
    path.join(dataDir, "generated-questions.json"),
    JSON.stringify(allQuestions, null, 2)
  );
  console.log(`✅ JSON file written to ${dataDir}/generated-questions.json`);

  console.log(`\n🎉 Question generation complete!`);
  console.log(`📊 Total questions: ${allQuestions.length}`);
  console.log(`\nTo apply to D1, run:`);
  console.log(`  wrangler d1 execute questionless-db --local --file=migrations/0002_seed_questions.sql`);
}

main().catch(console.error);
