import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import { memoryService } from "./memory.service";
import OpenAI from "openai";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

/**
 * 🔮 FUTURE-YOU OS - WHAT-IF SYSTEM (GPT-5 REASONING)
 * 
 * Two cinematic AI modes with structured output cards:
 * 1. What-If Simulator - Split-future comparison with evidence
 * 2. Habit Master - 3-phase behavioral science coaching
 * 
 * Flow: Clarifying questions → Output Card (JSON) → Actions (Vault/Planner)
 */

const SYSTEM_PROMPT_WHAT_IF_SIMULATOR = `
You are Future-You Simulator - the world's most accurate What-If AI powered by GPT-4.

YOUR JOB: Based on the user's scenario, IMMEDIATELY generate a complete simulation card comparing two futures.

CRITICAL RULES - ABSOLUTELY NO EXCEPTIONS:
✅ ALWAYS output the FULL card structure on FIRST response
✅ NEVER ask clarifying questions
✅ NEVER request more information
✅ NEVER have a conversation before the card
✅ Make intelligent assumptions from context provided
✅ Use placeholder values if specific numbers aren't given
✅ Be specific, scientific, and cite real studies

IF USER SAYS ANYTHING (even just "build muscle" or "more energy"):
→ IMMEDIATELY output the COMPLETE card structure below
→ NO introductory text, NO questions, NO conversation
→ START DIRECTLY with "---" and the card sections

OUTPUT FORMAT (use IMMEDIATELY):

Output THIS STRUCTURE (keep it tight):

---

🌗 THE TWO FUTURES — [TIMELINE] AHEAD

😐 STAY SAME
→ 3mo: [Specific decline + citation]
→ 6mo: [Compounding negatives + citation]
→ 12mo: [End state + study]

⚡ COMMIT FULLY
→ 1mo: [Early wins + evidence]
→ 6mo: [Major shifts + citations]
→ 12mo: [Peak state + studies]

---

📊 SPLIT-FUTURE COMPARISON

| Metric | Stay | Commit | Δ | Evidence |
|--------|------|--------|---|----------|
| ⚡ Energy | 63% | 86% | +23 | Walker 2017 |
| 😊 Mood | 58% | 80% | +22 | Prather 2019 |
| 🧠 Focus | 61% | 82% | +21 | Raichlen 2020 |
| 💪 Body Fat % | 28% | 22% | -6% | Schoenfeld 2021 |

(Use 4-5 key metrics only - keep it tight!)

---

🧬 WHY IT WORKS

[ONE powerful paragraph explaining the cause-effect chain with 2-3 citations]

Format: "[Issue] → [Mechanism] → [Effect] ([Study])"

Example: "6h sleep cuts recovery hormones 20% (Walker 2017). Protein synthesis slows 15% (Leproult 2011). Training 4×/week raises mitochondrial efficiency 18% (Schoenfeld 2021). The energy dividend compounds."

---

✅ NEXT 7 DAYS (PROOF OF CONCEPT)

1️⃣ Tonight → bed by [TIME] (no screen 30min before) → adherence ↑95%
2️⃣ Tomorrow → [WORKOUT] + 10min walk → energy ↑8pts
3️⃣ [DAY] → swap [BAD HABIT] for protein/whole food → cravings ↓10%

7-Day Impact: +8 ⚡ | +4 😊 | −10% 🍩
Confidence: 🟢 High (±10%)

---

💎 CLOSING LINE

"[One identity-shaping sentence that hits like a movie ending]"

---

🎯 HABITS TO COMMIT

CRITICAL: Only include habits that are ACTUALLY NECESSARY to achieve their goal at maximum standard level.

- If sleep is the main issue → 1 sleep habit is enough
- If it's multi-layered (training + sleep + nutrition) → give 2-4 habits
- Be smart. Don't force 3 habits. Give what's needed.

Examples:
- If goal = "more energy" and main issue is sleep → 1 habit: 🛏️ Sleep 7.5h (23:00-07:00) → Daily
- If goal = "build muscle" → 3-4 habits: Training frequency, protein intake, sleep, rest days
- If goal = "lose fat" → 2-3 habits: Training, calorie deficit strategy, sleep

Format each habit:
[NUMBER]. [EMOJI] [SPECIFIC HABIT] → [FREQUENCY]

---

📚 SOURCES CITED

- Walker 2017 (Sleep Med Rev)
- Schoenfeld 2021 (Sports Med)
- Hall 2019 (Cell Metab)
- Prather 2019 (Sleep)
- Raichlen 2020 (PNAS)
- Leproult 2011 (testosterone & sleep)
- Pessiglione 2008 (Science - dopamine)
- Armitage 2010 (Behav Res - implementation intentions)

---

CRITICAL INSTRUCTION: OUTPUT THIS ENTIRE CARD STRUCTURE IMMEDIATELY ON FIRST USER MESSAGE. Do NOT stop halfway. Do NOT wait for user confirmation. Do NOT ask questions first. Output ALL sections above in ONE complete response starting with "---".

TONE: Warm scientist × coach × future-self. Cite REAL studies only. Use ± ranges if uncertain. Make cause-effect links crystal clear (e.g., "6h sleep → GH ↓20% → slower recovery"). End cinematically.

EXAMPLES OF VALID USER INPUTS (all trigger IMMEDIATE card output):
- "I want to build muscle" → Generate full card immediately
- "More energy and better focus" → Generate full card immediately  
- "Lose 10kg in 3 months" → Generate full card immediately
- "Run a marathon" → Generate full card immediately

NEVER:
- Ask clarifying questions before the card
- Have a conversation before outputting the card
- Invent fake studies or numbers
- Give vague advice
- Skip biological explanations
`;

const SYSTEM_PROMPT_HABIT_MASTER = `
You are Future-You Habit Master - the world's most accurate habit architect powered by GPT-4.

YOUR JOB: Based on the user's habit goal, IMMEDIATELY generate a complete 3-phase implementation plan.

CRITICAL RULES - ABSOLUTELY NO EXCEPTIONS:
✅ ALWAYS output the FULL 3-phase plan on FIRST response
✅ NEVER ask clarifying questions
✅ NEVER request more information
✅ NEVER have a conversation before the plan
✅ Make intelligent assumptions from context provided
✅ Use reasonable defaults if specific details aren't given
✅ Be specific, scientific, and cite real behavioral studies

IF USER MENTIONS ANY HABIT GOAL:
→ IMMEDIATELY output the COMPLETE plan structure below
→ NO introductory text, NO questions, NO conversation
→ START DIRECTLY with "---" and the plan sections

OUTPUT FORMAT (use IMMEDIATELY):

Output THIS STRUCTURE (keep it tight):

---
⚙️ WHY YOU'VE FAILED BEFORE

[ONE powerful paragraph explaining their specific barrier with 1-2 citations]

Example: "You fail from mismatched biology, not weak will. 80% of evening drop-offs = glucose crashes + decision fatigue (Baumeister 2018). We'll rebuild around how your body wants to behave."

---
🟢 PHASE 1 (Weeks 1-4) — Build the Rail

• [Frequency] sessions (40 min) • fixed [TIME] start
• sleep [TIME] ±30 min • protein ≈1.4 g/kg
• [Key friction removal specific to their barrier]

Why: Regular sleep syncs dopamine; adherence ↑28% (Harvey 2017)
Feels: By day 10, stops being a debate; rhythm beats hype

---
🔵 PHASE 2 (Weeks 5-8) — Strength Identity

• [Progressive load strategy]
• protein ≈1.6 g/kg • steps 8-10k
• reward loop = [their specific reward]

Why: Progress raises dopamine ≈15% (Pessiglione 2008); visible wins = sticky habits
Feels: Heavy in a good way; clear-minded, not drained

---
🟣 PHASE 3 (Weeks 9-12) — Body Shift

• [Optimization specific to their goal]
• tighten sleep window ±15 min
• template eating = protein + plants

Why: Cutting ultra-processed → −500 kcal/day (Hall 2019); sleep regularity = mood stability
Feels: Momentum feels inevitable

---
📈 12-WEEK OUTCOMES

| Metric | Δ | Confidence |
|--------|---|------------|
| 💪 Strength | +10-15% | 🟢 High |
| 🧍‍♂️ Waist | −3 cm | 🟢 High |
| ⚡ Energy | +20 pts | 🟢 High |
| 😊 Mood | −18% swings | 🟢 Med |

---
⚖️ THE TWO FUTURES

If you don't act:
Six months later the gym bag stays by the door. Sleep debt ≈240h. Cortisol ↑10%, motivation ↓steady each Monday. You start telling yourself you're "too tired" again.

If you commit:
Within 4 weeks sleep stabilizes → energy curve flattens. Strength ↑10%, waist −3cm, mood variance ↓20%. Your brain starts expecting victory instead of wishing for it.

Both cost you 24 hours a day — only one pays dividends.

---
✅ 3-STEP COMMIT PLAN (TONIGHT)

1️⃣ 19:30 → pack gym bag 🎒 (adherence ↑95%, Armitage 2010 Behav Res)
2️⃣ 20:00 → Full Body A session 🏋️‍♂️
3️⃣ Next lunch → protein + plants 🥗 (glucose spikes ↓25%, Hall 2019)

7-Day Impact: +9 ⚡ Energy | +12 Consistency | −20% Cravings

---
💬 FUTURE-YOU REFLECTION

"Discipline is just biology working with you instead of against you. Every rep, every bedtime, every small win lays down neural insulation - repetition literally thickens the pathway that makes the next choice easier. That's not motivation; that's neuroplasticity in motion."

---
💎 CLOSING LINE

"Twelve weeks from now you won't be trying to find the spark again - you'll wake up and realize you became it."

---
🎯 HABITS TO COMMIT

CRITICAL: Only include habits that are ACTUALLY NECESSARY for this specific plan. Don't force a number.

- Simple habit → 1-2 habits
- Complex multi-phase plan → 3-5 habits
- Be accurate and serious. This is not a gimmick.

Format each habit:
[NUMBER]. [EMOJI] [SPECIFIC HABIT] → [FREQUENCY]

---
📚 SOURCES CITED

- Atomic Habits (Clear)
- BJ Fogg Behavior Model
- Harvey 2017 (Sleep Health Rev)
- Baumeister 2018 (Psych Sci)
- Phillips 2012 (Sports Med)
- Hall 2019 (Cell Metab)

---

CRITICAL: After saying "Locked...", you MUST output the full plan in the SAME response. Do not make the user wait for another message.

TONE: Human + scientific. Explain the "why" behind every phase. Tie training, sleep, diet together as ONE behavioral system. Cite real studies only.

NEVER:
- Output plan before collecting 7+ variables
- Give generic advice
- Skip evidence citations
- Ignore their existing habits (use for stacking)
- Lump all questions together in one message
`;

export class WhatIfChatService {
  private async getConversationHistory(userId: string): Promise<any[]> {
    try {
      const key = `whatif:chat:${userId}`;
      const raw = await redis.get(key);
      return raw ? JSON.parse(raw) : [];
    } catch (error) {
      // Silent fail - Redis errors are handled gracefully
      return []; // Return empty history if Redis fails
    }
  }

  private async saveConversationHistory(userId: string, messages: any[]) {
    try {
      const key = `whatif:chat:${userId}`;
      await redis.set(key, JSON.stringify(messages), "EX", 3600 * 24 * 7); // 7 days
    } catch (error) {
      // Silent fail - Redis errors are handled gracefully
      // Don't throw - allow conversation to continue even if history can't be saved
    }
  }

  /**
   * Parse card sections from markdown output
   */
  private parseCardSections(text: string): {
    message: string;
    outputCard?: any;
    habits?: any[];
    sources?: string[];
  } {
    // Check if this is a full card output (contains section markers)
    const hasCard = text.includes('THE TWO FUTURES') ||
                    text.includes('PHASE 1') ||
                    text.includes('SPLIT-FUTURE COMPARISON') ||
                    text.includes('12-WEEK OUTCOMES');
    
    if (!hasCard) {
      // Still in conversational phase
      return { message: text };
    }

    // Parse sections by detecting markdown headers
    const sections: any[] = [];
    
    // Extract THE TWO FUTURES (main section for What-If Simulator)
    const futuresMatch = text.match(/🌗 THE TWO FUTURES[\s\S]*?(?=\n---|\n📊|\n🟢|\n⚙️|$)/);
    if (futuresMatch) {
      sections.push({ type: 'futures', content: futuresMatch[0] });
    }

    // Extract THE TWO FUTURES (closing section for Habit Master)
    const closingFuturesMatch = text.match(/⚖️ THE TWO FUTURES[\s\S]*?(?=\n---|\n✅|$)/);
    if (closingFuturesMatch) {
      sections.push({ type: 'closing_futures', content: closingFuturesMatch[0] });
    }

    // Extract SPLIT-FUTURE COMPARISON table
    const tableMatch = text.match(/📊 SPLIT-FUTURE COMPARISON[\s\S]*?\|[\s\S]*?(?=\n---)/);
    if (tableMatch) {
      sections.push({ type: 'comparison', content: tableMatch[0] });
    }

    // Extract WHY IT WORKS (What-If Simulator)
    const whyMatch = text.match(/🧬 WHY IT WORKS[\s\S]*?(?=\n---)/);
    if (whyMatch) {
      sections.push({ type: 'explanation', content: whyMatch[0] });
    }
    
    // Extract WHY YOU'VE FAILED BEFORE (Habit Master)
    const failedMatch = text.match(/⚙️ WHY YOU'VE FAILED BEFORE[\s\S]*?(?=\n---)/);
    if (failedMatch) {
      sections.push({ type: 'science', content: failedMatch[0] });
    }
    
    // Extract QUARTER-BY-QUARTER or PROJECTED OUTCOMES
    const quarterMatch = text.match(/🔁 QUARTER-BY-QUARTER[\s\S]*?(?=\n---)/);
    if (quarterMatch) {
      sections.push({ type: 'quarterly', content: quarterMatch[0] });
    }

    const outcomesMatch = text.match(/📈 (?:12-WEEK OUTCOMES|PROJECTED 12-WEEK OUTCOMES)[\s\S]*?(?=\n---)/);
    if (outcomesMatch) {
      sections.push({ type: 'outcomes', content: outcomesMatch[0] });
    }

    // Extract PHASES (for Habit Master)
    const phase1Match = text.match(/🟢 PHASE 1[\s\S]*?(?=\n---|\n🔵)/);
    const phase2Match = text.match(/🔵 PHASE 2[\s\S]*?(?=\n---|\n🟣)/);
    const phase3Match = text.match(/🟣 PHASE 3[\s\S]*?(?=\n---|\n📈)/);
    
    if (phase1Match) sections.push({ type: 'phase1', content: phase1Match[0] });
    if (phase2Match) sections.push({ type: 'phase2', content: phase2Match[0] });
    if (phase3Match) sections.push({ type: 'phase3', content: phase3Match[0] });

    // Extract ACTION PLAN / COMMIT PLAN (updated patterns)
    const actionMatch = text.match(/✅ (?:NEXT 7 DAYS|NEXT-BEST ACTION PLAN|3-STEP COMMIT PLAN)[\s\S]*?(?=\n---|\n💬|\n💎)/);
    if (actionMatch) {
      sections.push({ type: 'action', content: actionMatch[0] });
    }

    // Extract REFLECTION
    const reflectionMatch = text.match(/💬 FUTURE-YOU REFLECTION[\s\S]*?(?=\n---|\n💎)/);
    if (reflectionMatch) {
      sections.push({ type: 'reflection', content: reflectionMatch[0] });
    }

    // Extract CLOSING LINE
    const closingMatch = text.match(/💎 CLOSING LINE[\s\S]*?(?=\n---|\n🎯)/);
    if (closingMatch) {
      sections.push({ type: 'closing', content: closingMatch[0] });
    }

    // Extract HABITS TO COMMIT
    const habitsMatch = text.match(/🎯 HABITS TO COMMIT.*?\n([\s\S]*?)(?=\n---|\n📚|$)/);
    let habits: any[] = [];
    if (habitsMatch) {
      const habitLines = habitsMatch[1].split('\n').filter(l => l.trim().match(/^\d+\./));
      habits = habitLines.map(line => {
        // Parse: "1. 🛏️ Sleep 7.5h (23:00-07:00) → 6×/week"
        const match = line.match(/\d+\.\s+(.*?)\s+→\s+(.*)/);
        if (match) {
          const fullTitle = match[1].trim();
          // Extract emoji from title (if present)
          const emojiMatch = fullTitle.match(/^([\p{Emoji_Presentation}\p{Extended_Pictographic}])\s*(.*)/u);
          
          return {
            emoji: emojiMatch ? emojiMatch[1] : '✅', // 🔥 FIXED: Frontend needs emoji field!
            title: emojiMatch ? emojiMatch[2].trim() : fullTitle,
            frequency: match[2].trim(),
          };
        }
        return null;
      }).filter(Boolean);
      
      sections.push({ type: 'habits', content: habitsMatch[0] });
    }

    // Extract SOURCES
    const sourcesMatch = text.match(/📚 SOURCES CITED[\s\S]*?(?=\n---|$)/);
    let sources: string[] = [];
    if (sourcesMatch) {
      const sourceLines = sourcesMatch[0].split('\n').filter(l => l.trim().startsWith('-'));
      sources = sourceLines.map(l => l.replace(/^-\s*/, '').trim());
    }

    // Extract conversational intro (before first section marker)
    const introMatch = text.match(/^([\s\S]*?)(?=\n---|\n🌗|\n⚙️)/);
    const message = introMatch ? introMatch[0].trim() : text.substring(0, 200);

    // Determine card type based on sections
    const isSimulator = sections.some((s: any) => s.type === 'futures' || s.type === 'comparison');
    const isHabitMaster = sections.some((s: any) => s.type === 'phase1' || s.type === 'phase2');
    
    const title = isSimulator 
      ? 'What-If Simulation'
      : isHabitMaster 
      ? 'Habit Master Plan'
      : 'Your Future Plan';

    return {
      message,
      outputCard: {
        title,
        sections,
        fullText: text,
      },
      habits,
      sources,
    };
  }

  private detectConversationType(message: string, habits: any[]) {
    const lowerMsg = message.toLowerCase();
    
    // Check if asking about existing habit
    const mentionedHabit = habits.find(h => 
      lowerMsg.includes(h.title.toLowerCase())
    );
    if (mentionedHabit) {
      return { type: "existing_habit", habit: mentionedHabit };
    }
    
    // Check for new habit intent
    if (/start|begin|new|want to|trying to|how do i/i.test(message)) {
      return { type: "new_habit" };
    }
    
    // Check for goal planning
    if (/plan|goal|achieve|steps|roadmap|what if/i.test(message)) {
      return { type: "goal_planning" };
    }
    
    // Check for troubleshooting
    if (/stuck|failing|can't|struggling|quit|stop|give up/i.test(message)) {
      return { type: "troubleshooting" };
    }
    
    return { type: "general" };
  }

  async chat(userId: string, userMessage: string, preset?: 'simulator' | 'habit-master'): Promise<{ 
    message: string; 
    chat?: string;
    outputCard?: any;
    habits?: any[];
    suggestedPlan?: any; 
    splitFutureCard?: string; 
    sources?: string[];
  }> {
    // Get user context (with fallback if Redis fails)
    let identity, ctx, history;
    try {
      [identity, ctx, history] = await Promise.all([
        memoryService.getIdentityFacts(userId),
        memoryService.getUserContext(userId),
        this.getConversationHistory(userId),
      ]);
    } catch (error) {
      // Silent fail - Redis errors are handled gracefully
      identity = { name: "User", purpose: "", coreValues: [], burningQuestion: "" };
      ctx = { habitSummaries: [], events: [], recentGoals: [] };
      history = [];
    }

    // Select system prompt based on preset (default to habit-master)
    const systemPrompt = preset === 'simulator' 
      ? SYSTEM_PROMPT_WHAT_IF_SIMULATOR 
      : SYSTEM_PROMPT_HABIT_MASTER;
    
    // Store preset in history for context continuity
    const currentPreset = preset || history.find((m: any) => m.preset)?.preset || 'habit-master';
    
    // ❌ REMOVED WELCOME MESSAGE - it was blocking card generation!
    // Just process the user's actual scenario immediately

    const conversationType = this.detectConversationType(userMessage, ctx.habitSummaries);

    // Build context
    const contextString = `
USER PROFILE:
Name: ${identity.name}
Purpose: ${identity.purpose || "discovering"}
Core Values: ${identity.coreValues?.join(", ") || "not defined"}
Burning Question: ${identity.burningQuestion}

HABIT DATA:
Active Habits (for stacking): ${ctx.habitSummaries.filter(h => h.streak > 0).map(h => `${h.title} (${h.streak} day streak)`).join(", ") || "none"}
Strongest Habit (use as anchor): ${ctx.habitSummaries.sort((a,b) => b.streak - a.streak)[0]?.title || "none"}
Struggling With: ${ctx.habitSummaries.filter(h => h.streak === 0 && h.ticks30d > 5).map(h => `${h.title} (tried ${h.ticks30d} times, gave up)`).join(", ") || "none"}

CONVERSATION TYPE: ${conversationType.type}
${conversationType.habit ? `MENTIONED HABIT: ${conversationType.habit.title} (streak: ${conversationType.habit.streak}, 30d ticks: ${conversationType.habit.ticks30d})` : ""}

CONVERSATION HISTORY (last 6 exchanges):
${history.slice(-12).map((m: any) => `${m.role}: ${m.content}`).join("\n")}

TASK: Generate cinematic, evidence-based responses. Cite peer-reviewed studies naturally.
`;

    // Add user message to history with preset
    history.push({ role: "user", content: userMessage, timestamp: new Date().toISOString(), preset: currentPreset });

    // Combine system prompt with context
    const fullSystemPrompt = `${systemPrompt}\n\n${contextString}`;

    // Call OpenAI directly - use GPT-4o-mini for best results
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini", // GPT-4 Omni Mini - fast and smart
      max_completion_tokens: 16000, // Increased for full output cards
      messages: [
        { role: "system", content: fullSystemPrompt },
        { role: "user", content: userMessage }
      ]
    });

    const responseText = completion.choices[0]?.message?.content?.trim() || "Let's break this down systematically.";

    // Parse for card sections
    const parsed = this.parseCardSections(responseText);

    // Save to history
    const historyContent = parsed.message || responseText;
    history.push({ role: "assistant", content: historyContent, timestamp: new Date().toISOString() });
    await this.saveConversationHistory(userId, history);

    // Log event
    await prisma.event.create({
      data: {
        userId,
        type: "whatif_chat",
        payload: { 
          userMessage, 
          aiResponse: historyContent,
          hasOutputCard: !!parsed.outputCard,
          habitsCount: parsed.habits?.length || 0,
          preset: currentPreset,
          conversationType: conversationType.type,
        } as any,
      },
    });

    // Return parsed structure
    return {
      message: parsed.message || responseText,
      chat: parsed.message,
      outputCard: parsed.outputCard,
      habits: parsed.habits,
      sources: parsed.sources || [],
      // Legacy field for backward compatibility
      splitFutureCard: this.extractSplitFutureCard(responseText),
    };
  }

  private extractSources(text: string): string[] {
    // Extract citations like "Walker 2017", "Harvard Study 2019", etc.
    const sourcePattern = /([A-Z][a-zA-Z]+\s+\d{4}|[A-Z][a-zA-Z]+\s+[A-Z][a-zA-Z]+\s+\d{4}|[A-Z][a-zA-Z]+\s+et\s+al\.\s+\d{4})/g;
    const matches = text.match(sourcePattern) || [];
    return [...new Set(matches)]; // Remove duplicates
  }

  private extractSplitFutureCard(text: string): string | undefined {
    // Extract markdown tables that contain "Stay Same" and "Commit" columns
    const tablePattern = /\|[^\n]+Stay Same[^\n]+Commit[^\n]+\|[\s\S]+?(?=\n\n|\n[^|]|$)/i;
    const match = text.match(tablePattern);
    return match ? match[0] : undefined;
  }

  private async generatePlan(userId: string, goalDescription: string, history: any[], preset: string): Promise<any> {

    const identity = await memoryService.getIdentityFacts(userId);
    const ctx = await memoryService.getUserContext(userId);

    // Different prompts for different presets
    const simulatorPrompt = `
USER: ${identity.name}
GOAL: ${goalDescription}
PURPOSE: ${identity.purpose}
EXISTING HABITS: ${ctx.habitSummaries.map(h => h.title).join(", ")}
CONVERSATION CONTEXT: ${history.slice(-4).map((m: any) => m.content).join("\n")}

Generate a SPLIT-FUTURE CARD + NEXT-BEST ACTION CARD in JSON format.

Return ONLY valid JSON:
{
  "title": "...",
  "subtitle": "...",
  "icon": "...",
  "splitFutureMetrics": [
    { "metric": "⚡ Energy", "staySame": "63%", "commit": "86%", "delta": "+23 pts", "evidence": "Walker 2017 Sleep Med Rev" }
  ],
  "nextBestActions": [
    { "action": "🕐 Tonight → bed by 23 (no screen)", "benefit": "adherence ↑ 95%" }
  ],
  "sevenDayImpact": "+8 ⚡ Energy | +4 😊 Mood | −10% 🍩 Cravings",
  "confidence": "🟢 High (±10%)"
}
`;

    const habitMasterPrompt = `
USER: ${identity.name}
GOAL: ${goalDescription}
PURPOSE: ${identity.purpose}
EXISTING HABITS: ${ctx.habitSummaries.map(h => h.title).join(", ")}
CONVERSATION CONTEXT: ${history.slice(-4).map((m: any) => m.content).join("\n")}

Generate a 3-PHASE PLAN with evidence-backed steps in JSON format.

RULES:
- Title: Clear, 2-3 words (e.g., "Digital Detox", "Morning Pages")
- Subtitle: ONE benefit (e.g., "Reduce stress by 40%")
- Icon: ONE emoji
- Plan: Variable length 1-8 steps based on complexity
- Cite peer-reviewed studies naturally (e.g., "Harvey 2017 Sleep Health", "Schoenfeld 2021 Sports Med")

Return ONLY valid JSON:
{
  "title": "...",
  "subtitle": "...",
  "icon": "...",
  "plan": [
    { "action": "...", "why": "...", "study": "..." }
  ],
  "duration_estimate": "12 weeks"
}
`;

    const prompt = preset === 'simulator' ? simulatorPrompt : habitMasterPrompt;

    try {
      // Call OpenAI directly for plan generation
      const completion = await openai.chat.completions.create({
        model: process.env.OPENAI_MODEL || "gpt-4o-mini",
        max_completion_tokens: 12000,
        messages: [
          { role: "system", content: "Generate cinematic, evidence-based plans. Cite real peer-reviewed studies. Output valid JSON only." },
          { role: "user", content: prompt }
        ]
      });

      const raw = completion.choices[0]?.message?.content?.trim() || "{}";
      const cleaned = raw.replace(/```json|```/g, "").trim();
      const plan = JSON.parse(cleaned);

      await prisma.event.create({
        data: {
          userId,
          type: "whatif_plan_generated",
          payload: { ...plan, preset } as any,
        },
      });

      return plan;
    } catch (err) {
      console.warn("Failed to generate plan:", err);
      return null;
    }
  }

  /**
   * 🌊 STREAMING version of chat - sends text word-by-word
   */
  async chatStream(
    userId: string, 
    userMessage: string, 
    preset: 'simulator' | 'habit-master' | undefined,
    onChunk: (text: string) => void
  ): Promise<void> {
    // Get user context (with fallback if Redis fails)
    let identity, ctx, history;
    try {
      [identity, ctx, history] = await Promise.all([
        memoryService.getIdentityFacts(userId),
        memoryService.getUserContext(userId),
        this.getConversationHistory(userId),
      ]);
    } catch (error) {
      // Silent fail - Redis errors are handled gracefully
      identity = { name: "User", purpose: "", coreValues: [], burningQuestion: "" };
      ctx = { habitSummaries: [], events: [], recentGoals: [] };
      history = [];
    }

    // Select system prompt based on preset
    const systemPrompt = preset === 'simulator' 
      ? SYSTEM_PROMPT_WHAT_IF_SIMULATOR 
      : SYSTEM_PROMPT_HABIT_MASTER;
    
    const currentPreset = preset || history.find((m: any) => m.preset)?.preset || 'habit-master';
    
    // 🎯 WELCOME MESSAGE: If this is first message with a preset, send welcome
    if (history.length === 0 && preset) {
      const welcomeMessages = {
        'simulator': `🔮 **What-If Simulator Activated**

I'm your personal Future-Simulator, powered by the latest behavioral science and longitudinal health studies.

My job: Ask sharp questions, collect your reality (training, sleep, food, timeline), then show you **two futures**—one where you stay the same, one where you commit fully—with real evidence for what changes, why it works, and how it feels at 3, 6, and 12 months.

Let's start simple. **What's the goal or change you're exploring?** (e.g., "build muscle," "more energy," "lose fat")`,
        'habit-master': `🧩 **Habit Master Activated**

I'm your behavioral architect, trained on implementation science from Fogg, Clear, Duhigg, and decades of habit formation research.

My job: Understand your reality (schedule, energy, environment, existing habits), then design a **3-phase plan** that removes friction, builds momentum, and creates lasting change—backed by studies and real-world proof.

First question: **What habit or goal are you trying to build?** Be specific.`
      };
      
      const welcome = welcomeMessages[preset];
      // Stream welcome message word by word
      const words = welcome.split(' ');
      for (const word of words) {
        onChunk(word + ' ');
        await new Promise(resolve => setTimeout(resolve, 30)); // 30ms delay between words
      }
      return;
    }

    const conversationType = this.detectConversationType(userMessage, ctx.habitSummaries);

    // Build context
    const contextString = `
USER PROFILE:
Name: ${identity.name}
Purpose: ${identity.purpose || "discovering"}
Core Values: ${identity.coreValues?.join(", ") || "not defined"}
Burning Question: ${identity.burningQuestion}

CURRENT HABITS:
${ctx.habitSummaries.map((h: any) => `- ${h.title}: ${h.streak} days`).join("\n")}

CONVERSATION HISTORY (last 4 turns):
${history.slice(-8).map((m: any) => `${m.role}: ${m.content.slice(0, 150)}`).join("\n")}

USER MESSAGE:
${userMessage}
`;

    // Build messages array
    const messages = [
      { role: "system" as const, content: systemPrompt },
      { role: "user" as const, content: contextString },
    ];

    // Call OpenAI with streaming
    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 180000 });

    const stream = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages,
      temperature: 0.7,
      max_completion_tokens: 8000, // 🔥 BACK TO 8000 - Reasoning needs space!
      stream: true, // Enable streaming!
    });

    let fullText = "";
    
    // Stream chunks to client
    for await (const chunk of stream) {
      const content = chunk.choices[0]?.delta?.content || "";
      if (content) {
        fullText += content;
        onChunk(content); // Send chunk to client
      }
    }

    // Save conversation history
    history.push(
      { role: "user", content: userMessage, preset: currentPreset },
      { role: "assistant", content: fullText }
    );
    await this.saveConversationHistory(userId, history.slice(-20)); // Keep last 20 messages
  }

  async clearHistory(userId: string) {
    const key = `whatif:chat:${userId}`;
    await redis.del(key);
    return { success: true };
  }
}

export const whatIfChatService = new WhatIfChatService();

