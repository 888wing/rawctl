/**
 * Generate UK Driving Theory Test questions using Gemini AI
 * Run with: npx tsx scripts/generate-driving-questions.ts
 *
 * Generates 50+ questions per topic based on Highway Code knowledge.
 * Output: migrations/0005_seed_driving_questions.sql
 */

import * as fs from "fs";
import * as path from "path";

// Load .env.local
const envPath = path.join(process.cwd(), ".env.local");
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, "utf-8");
  envContent.split("\n").forEach((line) => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith("#")) {
      const [key, ...valueParts] = trimmed.split("=");
      const value = valueParts.join("=");
      if (key && value) process.env[key] = value;
    }
  });
}

const GEMINI_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

const DRIVING_TOPICS = [
  {
    topic: "Alertness",
    dbName: "Alertness",
    content: `
      Observation at junctions - look, assess, decide, act.
      Use mirrors before signalling, changing direction, changing speed.
      Mirror-Signal-Manoeuvre (MSM) routine.
      Blind spots - areas not covered by mirrors. Check over shoulder.
      Anticipating actions of other road users - pedestrians, cyclists, motorcyclists.
      Awareness of vulnerable road users at junctions.
      Distractions: mobile phones, loud music, eating/drinking, satellite navigation.
      Using a hand-held mobile phone while driving is illegal.
      Tiredness - take a break every 2 hours, fresh air, caffeine drinks temporary.
      Signs of tiredness: difficulty concentrating, yawning, heavy eyelids.
      Motorway driving can cause drowsiness due to monotony.
      If feeling sleepy: stop at services, short nap (15 mins), drink caffeine.
      Never stop on hard shoulder to rest.
    `,
  },
  {
    topic: "Attitude",
    dbName: "Attitude",
    content: `
      Considerate driving - be patient, don't rush other drivers.
      Road rage - avoid confrontation, stay calm, don't retaliate.
      Tailgating is dangerous and intimidating. Maintain safe distance.
      Flashing headlights - only to let others know you're there, not to intimidate.
      Horn use - to alert others of your presence, not to express frustration.
      Don't use horn between 11:30pm and 7am in built-up areas (except emergency).
      Give way to emergency vehicles - pull over safely, don't panic.
      Priority on narrow roads - vehicle closest to passing place gives way.
      Courtesy - acknowledge when someone gives way.
      Dealing with slow-moving vehicles - be patient, overtake safely when possible.
      Large vehicles need more room to turn - don't cut in.
      Cyclists and motorcyclists - give them plenty of room.
      Horses and riders - slow down, give wide berth, don't rev engine.
      Pedestrians at crossings - always give way at zebra crossings.
    `,
  },
  {
    topic: "Safety and Your Vehicle",
    dbName: "Safety and Your Vehicle",
    content: `
      Regular vehicle maintenance checks essential for safety.
      Tyres: minimum 1.6mm tread depth across central 3/4 of width.
      Check tyre pressures when cold. Uneven wear indicates problems.
      Brakes: should work evenly, not pull to one side.
      Brake fluid reservoir should be between min and max marks.
      Lights: check all lights working regularly, replace bulbs promptly.
      Windscreen wipers and washers must work effectively.
      Windscreen damage - chips or cracks in driver's line of vision = MOT failure.
      Engine oil: check regularly, top up if needed.
      Coolant: check level when engine cold. Overheating = stop safely.
      Power steering fluid: top up if heavy steering develops.
      Battery: corrosion on terminals, ensure secure.
      Exhaust emissions: excessive smoke indicates problems.
      MOT test required annually for vehicles 3+ years old.
      Insurance: minimum third-party required by law.
      Vehicle registration document (V5C) - keeper details.
      SORN (Statutory Off Road Notification) if vehicle not taxed/used on road.
      Catalytic converter reduces harmful exhaust emissions.
      Head restraints prevent whiplash - adjust to top of ears/top of head.
      Child car seats: rear-facing for babies, appropriate seat by age/weight/height.
      Seatbelts: driver responsible for all passengers under 14.
    `,
  },
  {
    topic: "Safety Margins",
    dbName: "Safety Margins",
    content: `
      Stopping distance = thinking distance + braking distance.
      At 30mph: thinking 9m + braking 14m = 23m total (6 car lengths).
      At 50mph: thinking 15m + braking 38m = 53m (13 car lengths).
      At 70mph: thinking 21m + braking 75m = 96m (24 car lengths).
      Two-second rule: gap to vehicle ahead on dry road.
      In wet conditions: double the distance (four-second rule).
      In icy conditions: stopping distances can be x10.
      Aquaplaning: tyres lose contact with road surface in standing water.
      If aquaplaning: ease off accelerator, don't brake suddenly.
      Skidding: caused by harsh braking, acceleration, or steering.
      If skid: steer into the skid (direction rear is sliding).
      ABS (Anti-lock Braking System): prevents wheels locking under heavy braking.
      ABS allows steering while braking hard. Don't pump brakes with ABS.
      Fog: use dipped headlights, rear fog lights when visibility below 100m.
      Switch off fog lights when visibility improves - they dazzle.
      Black ice: road looks wet but is frozen. Steer gently, brake gently.
      Wind: high-sided vehicles, motorcycles, cyclists affected by crosswinds.
      Speed limits: 30mph built-up, 60mph single carriageway, 70mph dual/motorway.
    `,
  },
  {
    topic: "Hazard Awareness",
    dbName: "Hazard Awareness",
    content: `
      Hazard perception: scanning road ahead, anticipating danger.
      Look well ahead - the further you look, the earlier you spot hazards.
      Junctions: most accidents happen at junctions. Extra caution needed.
      Pedestrians: near schools, shops, bus stops, crossings.
      Children: unpredictable behaviour near roads.
      Elderly pedestrians: may be slower, may not hear approaching vehicles.
      Cyclists: check blind spots, give space when overtaking (1.5m minimum).
      Motorcyclists: harder to see, check mirrors carefully.
      Parked vehicles: doors may open, pedestrians may step out.
      Road markings: hatched areas, double white lines, zig-zag lines near crossings.
      Traffic calming: speed bumps, chicanes, width restrictions.
      Level crossings: stop when lights flash, barriers down, alarm sounds.
      Railway crossings without barriers: stop, look, listen before crossing.
      Animals on road: slow down, be prepared to stop.
      Contraflow systems: lanes may be narrower, less room for error.
      Road works: reduce speed, follow temporary signals.
      Pelican crossing: flashing amber means give way to pedestrians still crossing.
      Toucan crossing: cyclists and pedestrians share.
      Puffin crossing: detects pedestrians, no flashing amber phase.
    `,
  },
  {
    topic: "Road Signs",
    dbName: "Road Signs",
    content: `
      Circular signs: give orders. Red circle = prohibition. Blue circle = instruction.
      Triangular signs: give warnings. Red border triangle = warning.
      Rectangular signs: give information. Blue = motorway. Green = primary route. White = local.
      Stop sign: octagonal, must stop at line. Give way: inverted triangle.
      No entry: red circle with white horizontal bar.
      One way: blue rectangle with white arrow.
      Speed limit: red circle with number. National speed limit: white circle with black diagonal.
      No overtaking: two cars in red circle (red car on right).
      Roundabout ahead: triangle with circular arrows.
      Traffic lights ahead: triangle with traffic light symbol.
      Pedestrian crossing ahead: triangle with people crossing.
      School crossing patrol: triangle with children.
      Double white lines centre of road: do not cross if solid line nearest you.
      Broken white lines: can cross if safe.
      Motorway signs: blue background.
      Primary route signs: green with white text.
      Tourist attraction signs: brown background.
      Clearway: no stopping at any time (red cross on blue background).
      Urban clearway: no waiting during stated times.
      Yellow lines: single = no waiting during times shown. Double = no waiting at any time.
      Red routes: no stopping at any time on red lines.
      Box junction: yellow cross-hatching. Don't enter unless exit clear.
      Mini roundabout: blue circle with white arrows. Give way to right.
    `,
  },
  {
    topic: "Rules of the Road",
    dbName: "Rules of the Road",
    content: `
      Drive on the left, overtake on the right.
      Lane discipline: keep to the left unless overtaking or turning right.
      Motorway: use left lane for normal driving. Middle/right for overtaking only.
      Don't undertake (pass on left) unless traffic in right lane is moving slower.
      Speed limits vary by road type and vehicle type.
      30mph applies to roads with street lights unless otherwise signed.
      Pedestrian crossings: stop when amber light flashing and pedestrians still crossing.
      Zebra crossing: give way to anyone on or about to step onto crossing.
      School crossing patrol: stop when they display sign.
      Bus lanes: check times of operation. Taxis/cyclists may be permitted.
      Tram lanes: don't drive in them.
      Cycle lanes: don't drive/park in them during operating hours.
      Box junctions: don't enter unless exit clear. Exception: turning right, waiting for gap.
      Traffic lights: red = stop. Red+amber = stop (about to change). Green = go if safe. Amber = stop unless unsafe to do so.
      Filter arrows: green arrow means you can go in that direction only.
      Reversing: don't reverse from a side road onto a main road.
      One-way streets: can overtake on either side.
      Dual carriageway: treat each carriageway as separate road.
      Parking: follow parking signs, don't park on double yellow lines.
      Emergency vehicles: pull over safely, don't panic, don't break the law.
    `,
  },
  {
    topic: "Road and Highway Conditions",
    dbName: "Road and Highway Conditions",
    content: `
      Motorway joining: use slip road to match speed of traffic. Give way to motorway traffic.
      Motorway leaving: use left indicator, don't slow until on slip road.
      Hard shoulder: emergencies only. Walk to emergency phone facing traffic.
      Smart motorways: hard shoulder may be used as running lane at peak times.
      Red X above lane: lane closed, do not use.
      Variable speed limits on smart motorways: must follow them.
      Breakdown on motorway: move to hard shoulder/emergency area, use hazard lights.
      Fog on motorway: reduce speed, increase following distance, use dipped headlights.
      Contraflow on motorway: reduced speed limits, narrow lanes, keep to lane.
      Country roads: narrow, blind bends, concealed junctions, slow vehicles.
      Single-track roads: use passing places, pull left to let oncoming traffic pass.
      Steep hills: use lower gear going down. Give way to vehicles coming up.
      Fords: check depth before crossing. Drive slowly through. Test brakes after.
      Road surface: potholes, loose gravel, mud, leaves, ice - adjust speed.
      Rain after dry spell: road especially slippery (oil and rubber on surface).
      Night driving: use dipped headlights in built-up areas.
      Main beam: don't dazzle other road users. Dip when vehicle approaching.
      Speed on wet roads: reduce speed, increase following distance.
      Winter driving: clear all ice/snow from windows before setting off.
    `,
  },
  {
    topic: "Vulnerable Road Users",
    dbName: "Vulnerable Road Users",
    content: `
      Pedestrians: most vulnerable road users, especially children and elderly.
      Children: may run into road without looking. Extra care near schools, parks, ice cream vans.
      Elderly pedestrians: may need more time to cross, may not hear you.
      Visually impaired: white stick, may have guide dog. Be patient at crossings.
      Deaf pedestrians: won't hear your horn or engine.
      Mobility scooter users: treat as pedestrians, give plenty of room.
      Cyclists: give at least 1.5m clearance when overtaking at up to 30mph.
      Cyclists at roundabouts: may take different position in lane. Give them room.
      Cyclists at junctions: check for cyclists before turning left (they may be alongside).
      Motorcyclists: harder to see, especially at junctions. Look twice.
      Motorcyclists in bad weather: more affected by wind, rain, road surface.
      Horse riders: slow down, give wide berth, don't rev engine or sound horn.
      Pass horses at walking pace (max 10-15mph).
      Animals on road: slow down, be prepared to stop.
      Farm vehicles: may be slow, wide, leave mud on road.
      School buses: children may cross road after getting off.
      Emergency vehicles: pull over safely, check mirrors first.
      Wheelchair users: may be low down, harder to see.
      Learner drivers: may stall, be hesitant, give extra space and patience.
    `,
  },
  {
    topic: "Vehicle Handling",
    dbName: "Vehicle Handling",
    content: `
      Steering: hold wheel at ten-to-two or quarter-to-three position.
      Smooth steering inputs: jerky movements can cause loss of control.
      Gear changes: match speed to gear. Don't coast in neutral.
      Engine braking: use lower gears on long downhill stretches.
      Wet road: longer stopping distances, risk of aquaplaning. Reduce speed.
      Icy road: highest gear possible to avoid wheel spin. Gentle inputs.
      Snow: use second gear to move off. Keep speed very low.
      Fog: use dipped headlights (not main beam - reflects back). Fog lights if visibility <100m.
      Wind: grip steering firmly. High-sided vehicles affected most.
      Crosswind: expect when passing gaps in hedges, bridges, open stretches.
      Towing: max speed 60mph. Check trailer lights and number plate.
      Roof rack: increases fuel consumption, drag, affects handling.
      Heavy load: adjust headlights, tyre pressures, allow extra braking distance.
      Cruise control: useful on motorway for steady speed. Don't use in rain/ice.
      ABS: allows steering under heavy braking. Don't pump brake pedal.
      Traction control: helps prevent wheel spin when accelerating.
      Electronic stability control: helps prevent skidding.
      Eco driving: smooth acceleration, maintain steady speed, anticipate traffic.
      Eco driving reduces fuel consumption and emissions.
      Engine idling: switch off engine if stationary for more than a minute.
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
  count: number
): Promise<GeneratedQuestion[]> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set in .env.local");

  const prompt = `You are a UK Driving Theory Test question generation expert. Generate practice questions based on the official Highway Code content below.

【Topic】
${topic}

【Highway Code Content】
${content}

【Requirements】
- Generate exactly ${count} multiple choice questions
- Each question has 4 options, only 1 correct answer
- Difficulty distribution: 30% easy, 40% medium, 30% hard
- Must be based ONLY on provided content, no fabricated facts
- Provide detailed explanation referencing the Highway Code
- Questions should test practical knowledge for safe driving
- Vary question types: "What should you do if...", "When must you...", "What does this sign mean...", "At what distance..."
- Make distractors plausible but clearly wrong

【Output Format (JSON only, no markdown)】
{
  "questions": [
    {
      "question": "Question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "difficulty": "easy|medium|hard",
      "explanation": "Explanation referencing Highway Code",
      "handbook_ref": "Key Highway Code rule",
      "topic": "${topic}"
    }
  ]
}

IMPORTANT: Return ONLY valid JSON, no markdown code blocks or additional text.`;

  console.log(`  Generating ${count} questions for: ${topic}...`);

  const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
      },
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Gemini API error: ${error}`);
  }

  const data = (await response.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("No response from Gemini");

  const cleanedText = text
    .replace(/```json\n?/g, "")
    .replace(/```\n?/g, "")
    .trim();

  const result = JSON.parse(cleanedText);
  console.log(`    Generated ${result.questions.length} questions`);
  return result.questions;
}

async function main() {
  console.log("🚗 Generating UK Driving Theory questions...\n");

  const allQuestions: GeneratedQuestion[] = [];

  for (const { topic, dbName, content } of DRIVING_TOPICS) {
    try {
      const questions = await generateQuestions(topic, content, 50);
      // Tag questions with DB name
      questions.forEach((q) => (q.topic = dbName));
      allQuestions.push(...questions);
      // Rate limit delay
      await new Promise((resolve) => setTimeout(resolve, 3000));
    } catch (error) {
      console.error(`Failed for ${topic}:`, error);
      try {
        console.log(`    Retrying with 25 questions...`);
        await new Promise((resolve) => setTimeout(resolve, 5000));
        const questions = await generateQuestions(topic, content, 25);
        questions.forEach((q) => (q.topic = dbName));
        allQuestions.push(...questions);
      } catch (retryError) {
        console.error(`    Retry also failed for ${topic}:`, retryError);
      }
    }
  }

  console.log(`\nTotal questions generated: ${allQuestions.length}`);

  // Generate SQL INSERT statements
  const escape = (s: string) => s.replace(/'/g, "''");
  const insertStatements = allQuestions.map((q, idx) => {
    const questionId = `q_drv_${Date.now()}_${idx}_${Math.random().toString(36).substring(7)}`;

    return `INSERT INTO questions (id, question, options, correct_index, difficulty, topic, explanation, handbook_ref, source, verified, exam)
VALUES ('${questionId}', '${escape(q.question)}', '${escape(JSON.stringify(q.options))}', ${q.correct_index}, '${q.difficulty}', '${escape(q.topic)}', '${escape(q.explanation || "")}', '${escape(q.handbook_ref || "")}', 'ai_generated', 1, 'driving-theory');`;
  });

  const sqlContent = insertStatements.join("\n\n");
  fs.writeFileSync("migrations/0005_seed_driving_questions.sql", sqlContent);
  console.log(`\nSQL written to migrations/0005_seed_driving_questions.sql`);

  // Also save as JSON for review
  fs.mkdirSync("data", { recursive: true });
  fs.writeFileSync(
    "data/driving-theory-questions.json",
    JSON.stringify(allQuestions, null, 2)
  );
  console.log(`JSON written to data/driving-theory-questions.json`);

  console.log(`\nTo apply to D1:`);
  console.log(
    `  npx wrangler d1 execute questionless-db --remote --file=migrations/0005_seed_driving_questions.sql`
  );
}

main().catch(console.error);
