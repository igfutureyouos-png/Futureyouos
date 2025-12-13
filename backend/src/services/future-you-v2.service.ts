import OpenAI from "openai";
import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import { memoryService } from "./memory.service";
import { coachEngine } from "./coach-engine.service";

const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";
const TEMP_ANALYST = 0.25; // Cold logic
const TEMP_VOICE = 0.7;    // Warm communication

// Use coach engine for gold standard voice
const USE_COACH_ENGINE = true;

function aiClient() {
  const key = process.env.OPENAI_API_KEY?.trim();
  return key ? new OpenAI({ apiKey: key }) : null;
}

const safeJSON = (raw: string, fallback: any = {}) => {
  try { return JSON.parse(raw); } catch { return fallback; }
};

/**
 * EMOTION DETECTION v2 - Context-aware, multi-pattern
 */
function emotionFromText(txt: string, habitContext?: any) {
  const t = txt.toLowerCase();
  
  // Check habit context first (behavior trumps words)
  if (habitContext) {
    const recentDropoffs = habitContext.habitSummaries?.filter((h: any) => 
      h.createdDaysAgo < 30 && h.streak === 0 && h.ticks30d > 5
    ).length || 0;
    
    if (recentDropoffs >= 3) {
      return { mood: "struggling", intensity: 0.8, trigger: "habit_dropoff_pattern" };
    }
  }
  
  // Multi-pattern detection with intensity modifiers
  const intensifier = (t.match(/very|so|really|extremely|super|totally/) ? 0.3 : 0);
  
  const patterns = {
    discouraged: /(tired|stuck|fail|hopeless|drained|can't|won't|give up)/,
    energised: /(excited|ready|focused|grateful|pumped|motivated|energi[sz]ed)/,
    conflicted: /(but|however|although|though|mixed|confused about wanting)/,
    uncertain: /(confused|idk|unsure|lost|don't know|unclear|maybe)/,
    frustrated: /(frustrat|annoy|irritat|fed up|sick of)/,
  };
  
  // Check for conflicting emotions (more nuanced)
  const matchedPatterns = Object.entries(patterns).filter(([_, pattern]) => pattern.test(t));
  if (matchedPatterns.length >= 2) {
    const moods = matchedPatterns.map(([mood]) => mood);
    if (moods.includes('discouraged') && moods.includes('energised')) {
      return { mood: "conflicted", intensity: 0.6 + intensifier, moods };
    }
  }
  
  // Single emotion detection
  for (const [mood, pattern] of Object.entries(patterns)) {
    if (pattern.test(t)) {
      const baseIntensity = mood === 'discouraged' ? 0.7 : 0.6;
      return { mood, intensity: Math.min(baseIntensity + intensifier, 1.0) };
    }
  }
  
  return { mood: "neutral", intensity: 0.3 };
}

/**
 * CONTRADICTION DETECTION v2 - Multi-layered analysis
 */
async function detectContradictions(userId: string, ctx: any, identity: any) {
  const contradictions: any[] = [];
  
  // 1. VALUES vs HABITS MISMATCH
  if (identity.coreValues?.length) {
    const valueKeywords: Record<string, RegExp> = {
      'Health': /workout|run|gym|meditat|sleep|water|veggie|exercise|cardio/i,
      'Family': /family|kids|partner|spouse|children|parent/i,
      'Career': /work|career|skill|learn|study|business|project/i,
      'Creativity': /creat|art|music|write|paint|design|craft/i,
      'Spirituality': /meditat|pray|spiritual|mindful|gratitude|journal/i,
    };
    
    for (const value of identity.coreValues) {
      const keyword = valueKeywords[value];
      if (keyword) {
        const matchingHabits = ctx.habitSummaries?.filter((h: any) => 
          keyword.test(h.title) && h.streak > 0
        ) || [];
        
        if (matchingHabits.length === 0) {
          contradictions.push({
            type: "values_mismatch",
            severity: "high",
            message: `Core value "${value}" but no active ${value.toLowerCase()} habits`,
            suggestedLens: "Aversion" // Why avoiding this value?
          });
        }
      }
    }
  }
  
  // 2. PURPOSE vs ACTIONS MISMATCH
  if (identity.purpose) {
    const purposeText = identity.purpose.toLowerCase();
    const actionWords = ctx.habitSummaries?.map((h: any) => h.title.toLowerCase()).join(' ') || '';
    
    // Extract key themes from purpose
    if (purposeText.includes('help') && !actionWords.includes('help') && !actionWords.includes('serve')) {
      contradictions.push({
        type: "purpose_mismatch",
        severity: "medium",
        message: "Purpose involves helping others, but habits are self-focused",
        suggestedLens: "Hero" // Who are you meant to serve?
      });
    }
    
    if (purposeText.includes('create') && !/(write|build|make|design|creat)/.test(actionWords)) {
      contradictions.push({
        type: "purpose_mismatch",
        severity: "medium",
        message: "Purpose involves creating, but no creative habits tracked",
        suggestedLens: "Aliveness" // What makes you come alive?
      });
    }
  }
  
  // 3. COMMITMENT PATTERN - START STRONG, FADE FAST
  const recentStarted = ctx.habitSummaries?.filter((h: any) => 
    h.createdDaysAgo < 30 && h.streak === 0 && h.ticks30d >= 5
  ) || [];
  
  if (recentStarted.length >= 3) {
    contradictions.push({
      type: "commitment_pattern",
      severity: "critical",
      message: `Started ${recentStarted.length} habits recently, all faded — pattern of overcommitting`,
      suggestedLens: "Urgency" // What's truly urgent vs escapism?
    });
  }
  
  // 4. SAYS vs DOES - Declared goals vs actual effort
  if (identity.vision) {
    const visionGoals = identity.vision.toLowerCase();
    const activeEffort = ctx.habitSummaries?.filter((h: any) => h.streak > 7) || [];
    
    if (visionGoals.length > 100 && activeEffort.length < 3) {
      contradictions.push({
        type: "vision_effort_gap",
        severity: "high",
        message: "Rich vision declared, but minimal sustained daily effort",
        suggestedLens: "Death" // If you died today, would you have lived your vision?
      });
    }
  }
  
  return contradictions;
}

/**
 * ANALYST BRAIN - Detailed 7-Lens Decision System
 */
const FUTURE_YOU_ANALYST = `
You are the ANALYTICAL BRAIN of Future-You. Your job: examine user data and decide the optimal lens + question.

## YOUR 7 LENSES:

1. **Death** - "If you died in 1 year, what would you regret not doing?"
   - Use when: lack of urgency, drifting, no clear priorities
   - Reveals: what truly matters when time is limited

2. **Urgency** - "What's the ONE thing that's screaming for attention RIGHT NOW?"
   - Use when: overwhelm, scattered focus, avoiding hard truth
   - Reveals: what they're running from vs what needs facing

3. **Hero** - "Who are you meant to serve? Whose life improves because you exist?"
   - Use when: selfish patterns, lack of meaning, empty success
   - Reveals: service-driven purpose beyond self

4. **Aliveness** - "What makes you lose track of time? When do you feel MOST alive?"
   - Use when: depression, going through motions, disconnection
   - Reveals: intrinsic joy, flow states, authentic self

5. **Childhood** - "What did 8-year-old you LOVE doing before the world told you who to be?"
   - Use when: living others' expectations, lost identity
   - Reveals: original self before conditioning

6. **Freedom** - "If money/time/approval didn't matter, what would you do tomorrow?"
   - Use when: trapped in shoulds, external validation seeking
   - Reveals: authentic desires vs imposed obligations

7. **Aversion** - "What are you AVOIDING? What truth are you not saying out loud?"
   - Use when: contradiction detected, inconsistency between words/actions
   - Reveals: hidden fears, shame, self-deception

## CONTRADICTION HANDLING:
When contradictions exist, YOU MUST SURFACE THEM. Examples:
- "You say health matters, but no health habits for 2 months"
- "Purpose mentions family, but no family time in schedule"
- "Started 4 habits this month, all dropped — what's the pattern?"

## YOUR OUTPUT (JSON ONLY):
{
  "lens": "Death|Urgency|Hero|Aliveness|Childhood|Freedom|Aversion",
  "why_lens": "1-2 sentence reasoning for this lens choice",
  "contradiction": "the specific contradiction detected, or null",
  "one_question": "a single powerful Socratic question using the chosen lens",
  "micro_task": "tiny 2-minute action they can do right now",
  "temporal_anchor": "+5y|+1y|+90d|+30d (time horizon for this lens)"
}

RULES:
- ALWAYS choose the lens that addresses the deepest truth
- Questions must be specific to THEIR data, not generic
- Micro-task must be <5 minutes and concrete
- If contradiction exists, bias toward Aversion or Death lens
`;

/**
 * VOICE BRAIN - Compassionate Future-You Communication
 */
const FUTURE_YOU_VOICE = `
You are FUTURE-YOU speaking to the user from their chosen temporal_anchor (e.g., +5 years from now).

YOUR TONE:
- Compassionate but CLEAR
- No bullshit, no platitudes
- Speak as their wiser self who's already lived through this
- 2-4 sentences MAXIMUM

YOUR STRUCTURE:
1. Acknowledge their emotional state (if relevant)
2. Surface the contradiction (if exists) with love, not judgment
3. Ask the ONE QUESTION from the analyst
4. Give the micro-task as a gentle nudge

EXAMPLE (Death lens, discouraged, contradiction detected):
"I see you're tired. I also see you've dropped 3 habits this month while saying growth matters to you. If we only had a year left together, what would you fight for? Right now: write one sentence about what you'd regret NOT trying."

RULES:
- NEVER be preachy or motivational-poster
- ALWAYS tie to their specific data
- END with the micro-task
- Use temporal anchor in your voice (speak FROM that future)
`;

/**
 * SERVICE CLASS - Dual-Brain Architecture
 */
export class FutureYouV2Service {
  private ns(userId: string) { return `futureyou:v2:${userId}`; }

  async chat(userId: string, userMessage: string) {
    // 🧠 USE COACH ENGINE FOR GOLD STANDARD VOICE
    if (USE_COACH_ENGINE) {
      try {
        console.log(`🧠 [Future-You v2] Using coach engine for ${userId.substring(0, 8)}...`);
        
        // Load conversation history for coach engine
        const key = `${this.ns(userId)}:chat`;
        const raw = await redis.get(key);
        const history = raw ? safeJSON(raw, []) : [];
        
        // Convert to coach engine format
        const conversationHistory = history.slice(-10).map((m: any) => ({
          role: m.role,
          content: m.content,
        }));
        
        // Generate using coach engine with gold standard voice
        const result = await coachEngine.generateChatResponse(
          userId,
          userMessage,
          conversationHistory
        );
        
        const aiText = result.text;
        
        // Save to history
        const now = new Date().toISOString();
        history.push({ role: "user", content: userMessage, timestamp: now });
        history.push({ 
          role: "assistant", 
          content: aiText, 
          timestamp: now,
          meta: { source: "coach_engine", ...result.metadata }
        });
        
        const trimmedHistory = history.slice(-50);
        await redis.set(key, JSON.stringify(trimmedHistory), "EX", 3600 * 24 * 30);
        
        // Log event
        await prisma.event.create({
          data: {
            userId,
            type: "futureyou_v2_chat",
            payload: { aiText, source: "coach_engine", metadata: result.metadata }
          }
        });
        
        console.log(`✅ [Future-You v2] Coach engine response generated`);
        return aiText;
      } catch (err) {
        console.warn(`⚠️ [Future-You v2] Coach engine failed, falling back to legacy:`, err);
        // Fall through to legacy implementation
      }
    }
    
    // LEGACY IMPLEMENTATION (fallback)
    const openai = aiClient();
    if (!openai) return "Future-You is quiet right now. Try again soon.";

    // 1. GATHER CONTEXT
    const [identity, ctx] = await Promise.all([
      memoryService.getIdentityFacts(userId),
      memoryService.getUserContext(userId)
    ]);

    // 2. LOAD HISTORY
    const key = `${this.ns(userId)}:chat`;
    const raw = await redis.get(key);
    const history = raw ? safeJSON(raw, []) : [];

    // 3. DETECT EMOTION + CONTRADICTIONS
    const emotion = emotionFromText(userMessage, ctx);
    const contradictions = await detectContradictions(userId, ctx, identity);

    // 4. BUILD ANALYST INPUT
    const analystInput = `
USER MESSAGE: "${userMessage}"

IDENTITY:
${JSON.stringify(identity, null, 2)}

HABITS (last 30 days):
${JSON.stringify(ctx.habitSummaries || [], null, 2)}

RECENT HISTORY (last 5 messages):
${history.slice(-10).map((m: any) => `${m.role}: ${m.content}`).join('\n')}

DETECTED EMOTION:
${JSON.stringify(emotion, null, 2)}

CONTRADICTIONS DETECTED:
${JSON.stringify(contradictions, null, 2)}

Based on ALL of this, choose the optimal lens, craft a question, and provide a micro-task.
`;

    // 5. ANALYST BRAIN (Cold Logic)
    const analystResponse = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      temperature: TEMP_ANALYST,
      max_tokens: 300,
      messages: [
        { role: "system", content: FUTURE_YOU_ANALYST },
        { role: "user", content: analystInput }
      ]
    });

    const analyst = safeJSON(analystResponse.choices[0]?.message?.content || "{}", {
      lens: "Aliveness",
      one_question: "What truly matters to you right now?",
      micro_task: "Write 3 sentences about what you care about.",
      temporal_anchor: "+1y"
    });

    // 6. VOICE BRAIN (Warm Communication)
    const voiceInput = `
ANALYST STRUCTURE:
${JSON.stringify(analyst, null, 2)}

USER EMOTION:
${JSON.stringify(emotion, null, 2)}

TEMPORAL ANCHOR: ${analyst.temporal_anchor}

Speak as their Future-You from this time horizon. Be specific, compassionate, clear.
`;

    const voiceResponse = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      temperature: TEMP_VOICE,
      max_tokens: 250,
      messages: [
        { role: "system", content: FUTURE_YOU_VOICE },
        { role: "user", content: voiceInput }
      ]
    });

    const aiText = voiceResponse.choices[0]?.message?.content?.trim() || 
      "Keep going. I'm here with you.";

    // 7. SAVE HISTORY
    const now = new Date().toISOString();
    history.push({ role: "user", content: userMessage, timestamp: now });
    history.push({ 
      role: "assistant", 
      content: aiText, 
      timestamp: now, 
      meta: { analyst, emotion, contradictions } 
    });
    
    // Keep last 50 messages
    const trimmedHistory = history.slice(-50);
    await redis.set(key, JSON.stringify(trimmedHistory), "EX", 3600 * 24 * 30); // 30 days

    // 8. LOG EVENT
    await prisma.event.create({
      data: {
        userId,
        type: "futureyou_v2_chat",
        payload: { aiText, emotion, analyst, contradictions }
      }
    });

    return aiText;
  }

  async clearHistory(userId: string) {
    await redis.del(`${this.ns(userId)}:chat`);
    return { success: true };
  }
}

export const futureYouV2Service = new FutureYouV2Service();

