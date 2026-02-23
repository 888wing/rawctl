/**
 * Expand question bank with additional questions from scraped handbook data
 * Run with: npx tsx scripts/expand-questions.ts
 */

import * as fs from 'fs';
import * as path from 'path';

// Load .env.local
const envPath = path.join(process.cwd(), '.env.local');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      const value = valueParts.join('=');
      if (key && value) process.env[key] = value;
    }
  });
}

const GEMINI_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

// Additional content for each topic - deeper handbook facts NOT in original seed
const EXPANSION_TOPICS = [
  {
    topic: "British History",
    content: `
      Henry VII strengthened central administration after Wars of the Roses.
      Henry VIII broke from Rome, married six times.
      Henry VIII's wives: Catherine of Aragon, Anne Boleyn, Jane Seymour, Anne of Cleves, Catherine Howard, Catherine Parr.
      Anne Boleyn executed at Tower of London, daughter was Elizabeth.
      Jane Seymour gave Henry son Edward, died after birth.
      Church of England established with king as head.
      Wales formally united with England via Act for Government of Wales.
      Edward VI strongly Protestant, Book of Common Prayer written by Thomas Cranmer.
      Mary I - Bloody Mary - persecuted Protestants.
      Elizabeth I re-established Church of England.
      1560 Scottish Parliament abolished papal authority.
      Mary Queen of Scots - Catholic, executed for plotting against Elizabeth.
      Sir Francis Drake circumnavigated world in Golden Hind.
      William Shakespeare 1564-1616, born Stratford-upon-Avon.
      Globe Theatre in London.
      Elizabeth I died 1603, James VI of Scotland became James I of England.
      King James Bible - still used in Protestant churches.
      English Civil War 1642 - Cavaliers (Royalists) vs Roundheads (Parliamentarians).
      Charles I executed 1649, England became Commonwealth republic.
      Oliver Cromwell became Lord Protector, conquered Ireland brutally.
      Restoration 1660 - Charles II returned from Netherlands.
      Great Plague 1665, Great Fire of London 1666.
      St Paul's Cathedral rebuilt by Sir Christopher Wren.
      Samuel Pepys wrote diary documenting the Great Fire.
      Habeas Corpus Act 1679 - cannot be held without charge.
      Royal Society - oldest surviving scientific society.
      Isaac Newton 1643-1727, Cambridge, discovered gravity, wrote Principia Mathematica.
      Glorious Revolution 1688 - William of Orange and Mary invited to rule.
      Battle of the Boyne 1690 - William defeated James II in Ireland.
      Bill of Rights 1689 confirmed Parliament's rights over the Crown.
      Free press from 1695 - newspapers without government license.
      Act of Union 1707 created Kingdom of Great Britain.
      Scotland kept own legal system, education, Presbyterian Church after Union.
      Sir Robert Walpole 1721-1742 - first Prime Minister, lived at 10 Downing Street.
      Bonnie Prince Charlie led 1745 Jacobite rebellion.
      Battle of Culloden 1746 - last battle on British soil.
      Robert Burns 1759-1796 - Scottish poet, wrote Auld Lang Syne.
      Adam Smith - The Wealth of Nations, father of modern economics.
      David Hume - major Scottish Enlightenment philosopher.
      Industrial Revolution - James Watt improved steam engine.
      Richard Arkwright developed water frame for spinning cotton.
      Captain James Cook mapped coast of Australia.
      Slave trade abolished on British ships 1807.
      Emancipation Act 1833 abolished slavery throughout British Empire.
      William Wilberforce - key anti-slavery campaigner.
      Battle of Trafalgar 1805 - Admiral Nelson killed, defeated Napoleon's fleet.
      Nelson's Column stands in Trafalgar Square, London.
      Battle of Waterloo 1815 - Duke of Wellington defeated Napoleon.
      Queen Victoria 1837-1901, reigned 64 years.
      Great Exhibition 1851 in Crystal Palace, Hyde Park.
      Florence Nightingale 1820-1910 - founder of modern nursing, Crimean War.
      Emmeline Pankhurst 1858-1928 - suffragette leader.
      Women over 30 given vote in 1918, equal to men at 21 in 1928.
      World War I 1914-1918. Over 2 million British casualties.
      World War II 1939-1945. Winston Churchill Prime Minister.
      Battle of Britain - RAF defended against German Luftwaffe.
      D-Day 6 June 1944 - Allied invasion of Normandy.
      Clement Attlee's government 1945 - created NHS and welfare state.
      NHS established 5 July 1948 - Aneurin Bevan was Health Secretary.
      Rudyard Kipling - Nobel Prize Literature 1907, wrote The Jungle Book.
    `,
  },
  {
    topic: "A Modern Thriving Society",
    content: `
      UK population over 67 million. England most populated part.
      London largest city with about 9 million.
      Edinburgh capital of Scotland, Cardiff capital of Wales, Belfast capital of Northern Ireland.
      Empire Windrush 1948 brought workers from Caribbean.
      Post-war immigration from India, Pakistan, Bangladesh, former colonies.
      EU expansion brought workers from Eastern Europe.
      Commonwealth - association of nations formerly part of British Empire.
      The Queen (now King) is head of the Commonwealth.
      UK became member of European Economic Community (EEC) in 1973.
      UK voted to leave the EU in June 2016 referendum.
      Official languages: English, Welsh (in Wales), Scottish Gaelic.
      Christianity main religion. Also Islam, Hinduism, Sikhism, Judaism, Buddhism.
      Church of England - established church with monarch as head.
      Church of Scotland - Presbyterian, independent of state.
      26 Church of England bishops sit in House of Lords.
      Freedom of religion guaranteed - practice any faith or none.
      St George's Day 23 April - patron saint of England.
      St Andrew's Day 30 November - patron saint of Scotland.
      St David's Day 1 March - patron saint of Wales.
      St Patrick's Day 17 March - patron saint of Northern Ireland/Ireland.
      Population percentage identifying as Christian has decreased.
      Census conducted every 10 years.
      Ethnic diversity concentrated in large urban areas.
    `,
  },
  {
    topic: "UK Government",
    content: `
      UK is a constitutional monarchy and parliamentary democracy.
      Parliament sovereign legislative authority, located at Westminster.
      House of Commons has 650 elected MPs from constituencies.
      House of Lords - life peers, hereditary peers, bishops.
      Speaker of the House chairs debates in Commons, politically neutral.
      PM chooses Cabinet - about 20 senior ministers.
      Chancellor of the Exchequer responsible for economy.
      Home Secretary responsible for immigration, law and order.
      Foreign Secretary manages relations with foreign countries.
      Opposition front bench is Shadow Cabinet.
      Leader of Opposition largest non-government party.
      Prime Minister's Questions (PMQs) every Wednesday.
      Whips ensure party members vote with party.
      Acts of Parliament - bills must pass both Houses then Royal Assent.
      Scottish Parliament in Edinburgh - Holyrood.
      Welsh Senedd (formerly Assembly) in Cardiff.
      Northern Ireland Assembly at Stormont, Belfast.
      Devolved matters: health, education, environment, transport.
      Reserved matters: defence, foreign affairs, immigration, taxation.
      Local councils run local services - refuse, libraries, planning.
      Council tax funds local government.
      Councillors elected by local residents.
      Mayor of London - separately elected, runs Greater London Authority.
      Commonwealth nations work together but are independent.
      NATO member - North Atlantic Treaty Organisation.
      United Nations Security Council permanent member.
    `,
  },
  {
    topic: "Laws and Rights",
    content: `
      Rule of law - everyone subject to the law, including government.
      Criminal law - Crown Prosecution Service (CPS) prosecutes in England/Wales.
      Procurator Fiscal prosecutes in Scotland.
      Civil law - disputes between individuals or organizations.
      Small claims procedure - claims up to specific amounts.
      Magistrates' Court - minor criminal cases, lay magistrates.
      Crown Court - serious criminal cases with jury of 12.
      High Court, Court of Appeal, Supreme Court hierarchy.
      Jury service - citizens 18-75 can be called.
      Legal aid available for those who can't afford lawyers.
      Human Rights Act 1998 - incorporated European Convention.
      Equality Act 2010 - protects against discrimination.
      Protected characteristics: age, disability, gender reassignment, marriage, pregnancy, race, religion, sex, sexual orientation.
      Children must attend school ages 5-16 (18 in England for education/training).
      Forced marriage is illegal.
      Female genital mutilation (FGM) is illegal.
      Domestic violence is a crime, protection orders available.
      Carrying a knife or weapon in public is illegal.
      Age restrictions: alcohol/tobacco 18, driving 17, voting 18.
      Drugs classified A (most harmful), B, C.
      Anti-social behaviour orders (ASBOs) and civil injunctions.
      Police can give fixed penalty notices for disorder.
      Independent Police Complaints Commission handles complaints.
      Ombudsman investigates complaints about public services.
    `,
  },
  {
    topic: "Geography",
    content: `
      United Kingdom: England, Scotland, Wales, Northern Ireland.
      Great Britain: the island of England, Scotland, Wales.
      British Isles: geographical term including Republic of Ireland.
      Crown Dependencies: Channel Islands (Jersey, Guernsey), Isle of Man.
      British Overseas Territories: Gibraltar, Falkland Islands, others.
      Ben Nevis highest mountain in UK (Scotland, 1,345m).
      Snowdon (Yr Wyddfa) highest mountain in Wales.
      Scafell Pike highest mountain in England.
      Loch Lomond largest freshwater lake in mainland Britain (Scotland).
      Loch Ness famous for monster legend (Scotland).
      Lake Windermere largest lake in England (Lake District).
      River Thames flows through London, about 346km.
      River Severn longest river in UK, about 354km.
      Giant's Causeway - UNESCO World Heritage Site in Northern Ireland.
      Edinburgh Castle sits on Castle Rock.
      Big Ben - bell in Elizabeth Tower, Palace of Westminster.
      Tower of London - historic fortress and Crown Jewels.
      Buckingham Palace - official London residence of monarch.
      National parks: Lake District, Snowdonia, Peak District, Dartmoor, etc.
      Pennines - mountain chain, backbone of England.
      Scottish Highlands - rugged terrain, low population.
      White Cliffs of Dover - chalk cliffs facing France.
      UK has temperate maritime climate - mild, wet.
      Major cities: London, Birmingham, Leeds, Glasgow, Manchester, Liverpool, Sheffield, Edinburgh.
      London Heathrow busiest UK airport.
      Motorway network: M1, M25 orbital, M4, M6.
      HS2 high-speed rail project.
    `,
  },
  {
    topic: "Culture and Traditions",
    content: `
      William Shakespeare 1564-1616 - widely regarded as greatest English playwright.
      Shakespeare plays: Hamlet, Othello, Macbeth, King Lear, The Tempest, Romeo and Juliet, A Midsummer Night's Dream, Much Ado About Nothing.
      Globe Theatre rebuilt near original site in London.
      Geoffrey Chaucer - The Canterbury Tales, father of English literature.
      Charles Dickens - Oliver Twist, A Christmas Carol, Great Expectations, David Copperfield.
      Jane Austen - Pride and Prejudice, Sense and Sensibility.
      Thomas Hardy - Far from the Madding Crowd, Tess of the d'Urbervilles.
      Robert Louis Stevenson - Treasure Island, Dr Jekyll and Mr Hyde.
      Sir Arthur Conan Doyle - Sherlock Holmes.
      Agatha Christie - world's best-selling fiction writer, Poirot, Miss Marple.
      Dylan Thomas - Welsh poet, Under Milk Wood, Do not go gentle into that good night.
      William Wordsworth - poet, The Lake District.
      Robert Burns - Scotland's national poet, To a Mouse, A Red, Red Rose.
      The Beatles - from Liverpool, most influential band.
      Music festivals: Glastonbury, Edinburgh Festival Fringe.
      British Museum - one of world's largest museums, free entry.
      National Gallery - Trafalgar Square, European paintings.
      Tate Modern - modern art, Bankside, London.
      National Trust - conservation charity, preserves historic properties.
      BBC founded 1922, oldest national broadcasting organisation.
      Turner Prize - contemporary art award.
      Brit Awards - British music awards.
      Pantomimes - traditional Christmas theatre.
      Fish and chips, roast beef and Yorkshire pudding.
      Haggis - Scottish dish from sheep offal, oats, suet.
      Afternoon tea tradition, pubs (public houses).
      Morris dancing - traditional English folk dance.
    `,
  },
  {
    topic: "Everyday Life",
    content: `
      NHS provides free healthcare at point of use, funded by taxation.
      Register with a GP (General Practitioner) near home.
      999 for emergencies (police, fire, ambulance).
      111 for non-emergency medical advice.
      Pharmacies give medicines and health advice.
      Education compulsory ages 5-16 (training until 18 in England).
      State schools free, follow National Curriculum.
      Key Stage tests (SATs) at various ages.
      GCSEs at 16, A-levels/Scottish Highers at 17-18.
      Universities charge tuition fees, student loans available.
      UK uses pounds sterling (£). Coins: 1p, 2p, 5p, 10p, 20p, 50p, £1, £2.
      Notes: £5, £10, £20, £50.
      Bank of England issues English notes.
      Scottish and Northern Ireland banks also issue banknotes.
      Council Tax - local tax for local services.
      National Insurance - pays for state pension and benefits.
      Income Tax collected by HMRC (Her Majesty's Revenue & Customs).
      Drive on the left side of the road.
      Speed limits: 30mph in built-up areas, 60mph single carriageways, 70mph motorways/dual carriageways.
      MOT test required annually for vehicles over 3 years old.
      TV licence required for watching live TV or BBC iPlayer.
      Recycling widely practiced - separate bins for different materials.
      Queuing is expected social behaviour.
      Tipping in restaurants 10-15%.
      Smoking banned in enclosed public spaces since 2007.
      Metric system mainly used, imperial for road distances (miles) and beer/cider (pints).
    `,
  },
  {
    topic: "Employment",
    content: `
      National Insurance number needed to work legally.
      National Minimum Wage - different rates by age.
      National Living Wage for workers 23 and over.
      Employment contract sets terms and conditions.
      Working Time Regulations - maximum 48 hours per week (opt-out available).
      Statutory paid holiday - 5.6 weeks per year.
      Statutory Sick Pay (SSP) from employer.
      Statutory Maternity Pay - up to 39 weeks.
      Shared Parental Leave available.
      Paternity leave for fathers/partners.
      Equal pay for equal work - Equality Act 2010.
      Discrimination illegal based on protected characteristics.
      Trade unions represent workers' interests.
      ACAS - Advisory, Conciliation and Arbitration Service.
      Employment tribunal hears workplace disputes.
      Jobcentre Plus helps people find work, claim benefits.
      Universal Credit replaced several older benefits.
      Self-employed must register with HMRC.
      Health and Safety at Work Act 1974.
      Employers must provide safe working environment.
      Redundancy - consultation required, statutory redundancy pay.
      Unfair dismissal protection after qualifying period.
      Whistleblowing - reporting wrongdoing, protection from retaliation.
      Zero-hours contracts - no guaranteed hours.
      Apprenticeships combine work and study.
      Right to request flexible working after 26 weeks.
    `,
  },
  {
    topic: "Becoming a Citizen",
    content: `
      British citizenship by birth (in UK to settled parent), descent, or naturalisation.
      Naturalisation: 5 years residence (3 if married to British citizen).
      Must be of good character.
      Must pass Life in the UK Test.
      English language requirement: B1 CEFR level or equivalent.
      Application to Home Office with fee.
      Citizenship ceremony required.
      Take oath of allegiance or affirmation.
      Pledge: "I will give my loyalty to the United Kingdom and respect its rights and freedoms."
      British passport applied for after citizenship.
      Indefinite Leave to Remain (ILR) - permanent residence status.
      ILR usually required before citizenship application.
      Citizens can vote in all UK elections.
      Citizens can stand for public office.
      Citizens can work without restrictions.
      Commonwealth citizens can vote in UK elections if resident.
      EU citizens (settled/pre-settled status) retain voting rights for local elections.
      Dual nationality is allowed.
      Citizenship can be lost in extreme circumstances.
      Rights come with responsibilities - respect law, community participation.
      Volunteering and community involvement encouraged.
      Jury service is civic duty.
      Register to vote - electoral register.
    `,
  },
  {
    topic: "Sports",
    content: `
      UK hosted Olympics in 1908, 1948, and 2012 (all in London).
      2012 Olympics main site in Stratford, East London.
      Paralympics originated from Dr Ludwig Guttmann at Stoke Mandeville hospital.
      Sir Roger Bannister first sub-4-minute mile in 1954.
      Sir Jackie Stewart three-time Formula 1 world champion.
      Bobby Moore captained England's 1966 World Cup winning team.
      Sir Ian Botham famous cricket captain, charitable walks.
      Torvill and Dean won 1984 Olympic ice dancing gold with Bolero.
      Sir Steve Redgrave won 5 consecutive Olympic rowing golds.
      Baroness Tanni Grey-Thompson won 16 Paralympic medals including 11 gold.
      Dame Kelly Holmes won 2 gold medals at 2004 Athens Olympics.
      Dame Ellen MacArthur fastest solo circumnavigation of the world 2004.
      Sir Chris Hoy won 6 Olympic cycling golds.
      David Weir won 6 Paralympic golds, 6 London Marathons.
      Bradley Wiggins first British Tour de France winner 2012.
      Mo Farah won 5000m and 10000m at 2012 Olympics.
      Jessica Ennis won heptathlon gold at 2012 Olympics.
      Andy Murray first British man to win US Open since 1936.
      Ellie Simmonds Paralympic swimming gold 2008 and 2012.
      Cricket originated in England, games can last up to 5 days (Test cricket).
      The Ashes - prestigious Test cricket series England vs Australia.
      Football most popular sport in UK.
      England won World Cup in 1966.
      English Premier League attracts large international audiences.
      Rugby originated in Rugby School in England.
      Six Nations Championship - England, Scotland, Wales, Ireland, France, Italy.
      Horse racing: Royal Ascot, Grand National at Aintree, Epsom Derby.
      Golf modern rules from 15th century Scotland, St Andrews home of golf.
      The Open Championship - oldest golf Major, held at British courses.
      Tennis modern form from late 19th century England.
      Wimbledon oldest tennis tournament, only Grand Slam on grass.
      Sir Francis Chichester first solo circumnavigation by sailing 1966/67.
      Formula 1 British Grand Prix at Silverstone.
      Lewis Hamilton multiple Formula 1 world champion.
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
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

  const prompt = `You are a Life in the UK Test question generation expert. Generate NEW practice questions based on the following official handbook content.

【Chapter Content】
${content}

【Topic】
${topic}

【Requirements】
- Generate exactly ${count} multiple choice questions
- Each question has 4 options, only 1 correct answer
- Difficulty distribution: 30% easy, 40% medium, 30% hard
- Must be based ONLY on provided content, no fabricated facts
- Provide detailed explanation referencing the handbook
- Questions should test factual knowledge: dates, names, places, achievements
- Make questions specific - avoid vague or subjective questions
- Vary question types: "When did...", "Who was...", "What is...", "Which...", "Where..."

【Output Format (JSON only, no markdown)】
{
  "questions": [
    {
      "question": "Question text in English",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "difficulty": "easy|medium|hard",
      "explanation": "Explanation text referencing the handbook",
      "handbook_ref": "Key fact from the content",
      "topic": "${topic}"
    }
  ]
}

IMPORTANT: Return ONLY valid JSON, no markdown code blocks or additional text.`;

  console.log(`Generating ${count} questions for: ${topic}...`);

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

  const data = await response.json() as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("No response from Gemini");

  const cleanedText = text
    .replace(/```json\n?/g, "")
    .replace(/```\n?/g, "")
    .trim();

  const result = JSON.parse(cleanedText);
  console.log(`  Generated ${result.questions.length} questions`);
  return result.questions;
}

async function main() {
  console.log("🚀 Expanding question bank...\n");

  const allQuestions: GeneratedQuestion[] = [];

  for (const { topic, content } of EXPANSION_TOPICS) {
    try {
      // Generate 60 questions per topic to reach 1000+ total
      const questions = await generateQuestions(topic, content, 60);
      allQuestions.push(...questions);
      // Rate limit delay
      await new Promise(resolve => setTimeout(resolve, 3000));
    } catch (error) {
      console.error(`Failed for ${topic}:`, error);
      // Try smaller batch on failure
      try {
        console.log(`  Retrying with 30 questions...`);
        await new Promise(resolve => setTimeout(resolve, 5000));
        const questions = await generateQuestions(topic, content, 30);
        allQuestions.push(...questions);
      } catch (retryError) {
        console.error(`  Retry also failed for ${topic}:`, retryError);
      }
    }
  }

  console.log(`\nTotal new questions generated: ${allQuestions.length}`);

  // Generate SQL INSERT statements
  const insertStatements = allQuestions.map((q, idx) => {
    const escape = (s: string) => s.replace(/'/g, "''");
    const questionId = `q_exp_${Date.now()}_${idx}_${Math.random().toString(36).substring(7)}`;

    return `INSERT INTO questions (id, question, options, correct_index, difficulty, topic, explanation, handbook_ref, source, verified, exam)
VALUES ('${questionId}', '${escape(q.question)}', '${escape(JSON.stringify(q.options))}', ${q.correct_index}, '${q.difficulty}', '${escape(q.topic)}', '${escape(q.explanation || '')}', '${escape(q.handbook_ref || '')}', 'ai_generated', 1, 'life-in-uk');`;
  });

  const sqlContent = insertStatements.join("\n\n");
  fs.writeFileSync("migrations/0005_expand_life_in_uk_questions.sql", sqlContent);
  console.log(`\nSQL written to migrations/0005_expand_life_in_uk_questions.sql`);

  fs.writeFileSync(
    "data/expanded-questions.json",
    JSON.stringify(allQuestions, null, 2)
  );
  console.log(`JSON written to data/expanded-questions.json`);

  console.log(`\nTo apply to D1:`);
  console.log(`  npx wrangler d1 execute questionless-db --remote --file=migrations/0005_expand_life_in_uk_questions.sql`);
}

main().catch(console.error);
