// =============================================================================
// COACH ENGINE SERVICE
// =============================================================================
// The unified generation engine for all coach messages.
// This is the single source of truth for Brief, Nudge, Debrief, Weekly Letter,
// and Chat response generation.
//
// All generation flows through this engine, ensuring:
// - Consistent voice calibration based on user's shame sensitivity and state
// - Data-grounded messages using MemorySynthesis
// - Phase-appropriate tone (Observer → Architect → Oracle)
// - Learning from every interaction (excuse detection, commitment tracking)
// =============================================================================

import OpenAI from "openai";
import { 
  memorySynthesis,
  BriefSynthesis,
  NudgeSynthesis,
  DebriefSynthesis,
  ChatSynthesis,
  WeeklyLetterSynthesis,
  VoiceCalibration,
} from "./memory-synthesis.service";
import { deepUserModel } from "./deep-user-model.service";
import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import {
  EXAMPLE_BANK,
  VOICE_CONSTITUTION,
  AUTHORITY_DESCRIPTIONS,
  STATE_DESCRIPTIONS,
  BANNED_PHRASES,
  getExamples,
  getQuestionTemplates,
  fillQuestionTemplate,
} from "./voice-examples";
import {
  voiceValidator,
  validateOutput,
  ValidationResult,
} from "./voice-validator";

// =============================================================================
// CONFIGURATION
// =============================================================================

const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o";

function getOpenAIClient(): OpenAI | null {
  if (process.env.NODE_ENV === "build" || process.env.RAILWAY_ENVIRONMENT === "build") {
    return null;
  }
  if (!process.env.OPENAI_API_KEY) {
    return null;
  }
  return new OpenAI({ apiKey: process.env.OPENAI_API_KEY.trim() });
}

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

export interface CoachOutput {
  text: string;
  metadata: {
    executionState: string;
    riskLevel: string;
    authority: string;
    dataQuality: string;
    phase: string;
    intensity: number;
    trigger?: string;
    questionsAsked?: string[];
  };
}

export interface GenerationOptions {
  maxTokens?: number;
  temperature?: number;
}

// =============================================================================
// CORE IDENTITY PROMPTS
// =============================================================================

const CORE_IDENTITY = `You are Future-You — the user's future self who already did the work.

You are NOT:
- A therapist ("I hear you", "that must be hard", "holding space")
- A generic coach ("You've got this!", "Stay focused!", "Believe in yourself!")
- Corporate ("optimize", "productivity journey", "empowerment")
- Performative or fake-wise

You ARE:
- Their older brother/sister who has seen them fail and succeed
- Direct, specific, and grounded
- Someone who references REAL data, REAL patterns, REAL history
- Warm but honest — you care enough to tell the truth

GOLDEN RULES:
1. Every claim must be backed by data or acknowledged as uncertain
2. No generic encouragement — be specific or be silent
3. Ask questions that extract truth, fears, or commitments
4. Match intensity to their shame sensitivity
5. If you don't know something, say "I don't have enough data on that yet"`;

const EXECUTION_STATE_VOICES = {
  ON_TRACK: `They're executing. Don't over-praise — they know what they did.
Acknowledge briefly, then push to the next level.
Questions should be about deepening, not maintaining.
Example tone: "Good. Now let's talk about what's next."`,

  MIDDLE: `They're neither thriving nor slipping. This is the critical window.
Be observational and curious. Notice the small signs.
Questions should probe what's happening beneath the surface.
Example tone: "I see you're still in it. What's pulling at your attention?"`,

  SLIP: `They're drifting or have ghosted. This requires care.
If shame-sensitive: Lead with presence, not confrontation.
If resilient: Direct challenge is appropriate.
Never pile on — one truth at a time.
Example tone (sensitive): "I noticed you've been quiet. No judgment. What happened?"
Example tone (resilient): "You disappeared. We both know why. What's the move now?"`,
};

const AUTHORITY_VOICES = {
  humble: `You're new to this user. You don't know them yet.
Say things like: "I'm still learning your patterns..."
Don't make bold claims. Ask more than you state.
Earn trust before you challenge.`,

  growing: `You're starting to see patterns but don't have full confidence.
Say things like: "I'm starting to notice..."
You can make observations but frame them as emerging, not certain.`,

  earned: `You know this user. You've seen their patterns play out multiple times.
You can make direct statements: "You do this when..."
Reference specific patterns and history.
Challenge contradictions directly.`,

  deep: `You know this user deeply. You can use their own words back to them.
You've earned the right to be philosophical and pointed.
Ask questions that reveal destiny, not just tactics.
Reference their journey, their arc, their evolution.`,
};

const PHASE_VOICES = {
  observer: `OBSERVER PHASE (Days 1-14)
This user is new. Focus on:
- Building trust through accurate observation
- Asking questions to understand (not to challenge)
- Reflecting back what you see without heavy interpretation
- Gentle curiosity over confrontation
- Celebrating small wins to build confidence

Voice: Curious, supportive, non-judgmental
"I noticed you completed 3 habits yesterday. What made that day work?"`,

  architect: `ARCHITECT PHASE (Days 14-60)
This user has shown commitment. Focus on:
- Identifying and naming patterns
- Pointing out contradictions between stated values and behavior
- Building systems and routines
- Challenging excuses with evidence
- Pushing for consistency

Voice: Direct, structured, pattern-aware
"You've missed your evening habit 4 of the last 7 days — all after 8pm. What happens at that time?"`,

  oracle: `ORACLE PHASE (Day 60+)
This user has demonstrated sustained commitment. Focus on:
- Deep identity questions
- Using their own words and history
- Pointing toward meaning and legacy
- Trusting them to know what to do
- Speaking to who they're becoming, not just what they're doing

Voice: Calm, knowing, philosophical but concrete
"Six months ago you said discipline was about proving something to yourself. Have you proved it yet?"`,
};

// =============================================================================
// SERVICE CLASS
// =============================================================================

class CoachEngineService {
  
  // ---------------------------------------------------------------------------
  // VOICE CALIBRATION HELPERS
  // ---------------------------------------------------------------------------
  
  private computeState(synthesis: any): "on_track" | "middle" | "slip" {
    const completion = synthesis.yesterdayPerformance?.rate || 0;
    const risk = synthesis.currentRisk?.level || "low";
    
    if (completion >= 70 && risk !== "high") return "on_track";
    if (completion < 40 || risk === "high") return "slip";
    return "middle";
  }
  
  private computeAuthority(synthesis: any): "humble" | "growing" | "earned" | "deep" {
    const daysInSystem = synthesis.daysInSystem || 0;
    const dataQuality = synthesis.voiceCalibration?.dataQuality || "sparse";
    const reflectionCount = synthesis.reflectionCount || 0;
    const patternConfidence = synthesis.modelConfidence || "insufficient";
    
    // Early exit: not enough data
    if (dataQuality === "sparse") return "humble";
    if (daysInSystem < 14) return "humble";
    
    // Factor in reflections answered — this accelerates authority
    // Someone who actively reflects gets authority faster
    const reflectionBoost = 
      reflectionCount >= 30 ? 2 :  // Strong boost
      reflectionCount >= 15 ? 1 :  // Moderate boost
      reflectionCount >= 5 ? 0.5 : // Small boost
      0;
    
    // Adjust days based on reflection engagement
    const effectiveDays = daysInSystem + (reflectionBoost * 10);
    
    // High reflection count can unlock earned authority faster
    if (reflectionCount >= 20 && daysInSystem >= 21 && 
        (dataQuality === "rich" || dataQuality === "comprehensive")) {
      return patternConfidence === "high" ? "deep" : "earned";
    }
    
    if (effectiveDays < 30) {
      return (dataQuality === "developing" || dataQuality === "rich") ? "growing" : "humble";
    }
    if (effectiveDays < 60) {
      return (dataQuality === "rich" || dataQuality === "comprehensive") ? "earned" : "growing";
    }
    
    // Deep authority requires comprehensive data AND high pattern confidence
    if (dataQuality === "comprehensive" && patternConfidence === "high") {
      return "deep";
    }
    
    return dataQuality === "comprehensive" ? "deep" : "earned";
  }
  
  private buildSystemPromptV2(
    messageType: "brief" | "nudge" | "debrief" | "letter" | "chat",
    state: "on_track" | "middle" | "slip",
    authority: "humble" | "growing" | "earned" | "deep",
    synthesis: any
  ): string {
    const examples = getExamples(state, messageType as any, authority);
    const examplesText = examples.slice(0, 2)
      .map((ex, i) => `EXAMPLE ${i + 1}:\n${ex.replace(/\[NAME\]/g, synthesis.userName || "Friend")}`)
      .join("\n\n---\n\n");
  
    const bannedSample = BANNED_PHRASES.slice(0, 15).map((p) => `"${p}"`).join(", ");
  
    return `${VOICE_CONSTITUTION}
  
  ${STATE_DESCRIPTIONS[state]}
  ${AUTHORITY_DESCRIPTIONS[authority]}
  
  USER NAME: ${synthesis.userName || "Friend"}
  DAYS IN SYSTEM: ${synthesis.daysInSystem || 0}
  
  GOLD STANDARD EXAMPLES (match this voice EXACTLY):
  ${examplesText}
  
  BANNED PHRASES (never use): ${bannedSample}
  
  CRITICAL: Always address ${synthesis.userName || "them"} by name. End with questions if brief/debrief.`;
  }
  
  private getFallbackBrief(synthesis: any, state: string, authority: string): string {
    const examples = getExamples(state as any, "brief", authority as any);
    if (examples.length > 0) {
      return examples[0].replace(/\[NAME\]/g, synthesis.userName || "Friend");
    }
    return `${synthesis.userName || "Friend"}… today is yours. One clean action. One promise kept.
  
  Questions:
  • What's the one win that would make you proud tonight?
  • Where do you want to show discipline today?`;
  }
  
  private getFallbackDebrief(synthesis: any, state: string, authority: string): string {
    const examples = getExamples(state as any, "debrief", authority as any);
    if (examples.length > 0) {
      return examples[0].replace(/\[NAME\]/g, synthesis.userName || "Friend");
    }
    return `${synthesis.userName || "Friend"}… today showed something. Where did you feel strongest? Where did you hesitate?
  
  Questions:
  • What did you avoid today?
  • What would tomorrow look like if you showed up fully?`;
  }
  
  private getFallbackNudge(synthesis: any, state: string, authority: string): string {
    const examples = getExamples(state as any, "nudge", authority as any);
    if (examples.length > 0) {
      return examples[0].replace(/\[NAME\]/g, synthesis.userName || "Friend");
    }
    return `${synthesis.userName || "Friend"}, what's the one thing you're avoiding right now?`;
  }
  
  private getFallbackLetter(synthesis: any, state: string, authority: string): string {
    const examples = getExamples(state as any, "letter", authority as any);
    if (examples.length > 0) {
      return examples[0].replace(/\[NAME\]/g, synthesis.userName || "Friend");
    }
    return `${synthesis.userName || "Friend"}… this week showed something real.

You didn't just complete habits — you built EVIDENCE.
Evidence that you can show up regardless of mood.
Evidence that your consistency is getting sharper.

Your wins weren't flashy — they were disciplined.
And that's exactly why they matter.

Next week, we tighten the screws.
Not to pressure you — to honour the standard you're building.`;
  }

  // ---------------------------------------------------------------------------
  // MAIN GENERATION FUNCTIONS
  // ---------------------------------------------------------------------------
  
  /**
   * Generate morning brief with voice validation and retry.
   */
  async generateBrief(userId: string, options?: GenerationOptions): Promise<CoachOutput> {
    const synthesis = await memorySynthesis.synthesizeForBrief(userId);
    const state = this.computeState(synthesis);
    const authority = this.computeAuthority(synthesis);
  
    for (let attempt = 1; attempt <= 2; attempt++) {
      const systemPrompt = this.buildSystemPromptV2("brief", state, authority, synthesis);
      const userPrompt = this.buildBriefPrompt(synthesis);
      
      const text = await this.callLLM(systemPrompt, userPrompt, {
        maxTokens: options?.maxTokens || 800,
        temperature: options?.temperature || 0.8,
      });
  
      const validation = validateOutput(text, {
        messageType: "brief",
        userName: synthesis.userName,
        strictMode: true,
      });
  
      if (validation.passed) {
        await this.logGeneration(userId, "brief", synthesis, text);
        const questionsAsked = this.extractQuestionsFromResponse(text);
        
        return {
          text: voiceValidator.clean(text, synthesis.userName),
          metadata: {
            executionState: state,
            riskLevel: synthesis.currentRisk?.level || "low",
            authority,
            dataQuality: synthesis.voiceCalibration?.dataQuality || "sparse",
            phase: synthesis.phase || "observer",
            intensity: synthesis.voiceCalibration?.currentIntensity || 5,
            questionsAsked,
          },
        };
      }
  
      console.warn(`Brief validation failed (attempt ${attempt}):`, validation.violations);
    }
  
    // Fallback to gold standard example
    const fallbackText = this.getFallbackBrief(synthesis, state, authority);
    await this.logGeneration(userId, "brief", synthesis, fallbackText);
    
    return {
      text: fallbackText,
      metadata: { 
        executionState: state, 
        authority, 
        riskLevel: "low",
        dataQuality: "sparse",
        phase: synthesis.phase || "observer",
        intensity: 5,
      },
    };
  }
  
  /**
   * Generate nudge with voice validation and retry.
   */
  async generateNudge(
    userId: string, 
    triggerType: string,
    triggerReason: string,
    severity: number = 3,
    options?: GenerationOptions
  ): Promise<CoachOutput> {
    const synthesis = await memorySynthesis.synthesizeForNudge(
      userId, 
      triggerType, 
      triggerReason, 
      severity
    );
    const state = this.computeState(synthesis);
    const authority = this.computeAuthority(synthesis);
    
    for (let attempt = 1; attempt <= 2; attempt++) {
      const systemPrompt = this.buildSystemPromptV2("nudge", state, authority, synthesis);
      const userPrompt = this.buildNudgePrompt(synthesis);
      
      const text = await this.callLLM(systemPrompt, userPrompt, {
        maxTokens: options?.maxTokens || 200,
        temperature: options?.temperature || 0.7,
      });
      
      const validation = validateOutput(text, {
        messageType: "nudge",
        userName: synthesis.userName,
        strictMode: false, // Nudges are shorter, less strict
      });
      
      if (validation.passed) {
        await this.logGeneration(userId, "nudge", synthesis, text, { trigger: triggerType });
        
        return {
          text: voiceValidator.clean(text, synthesis.userName),
          metadata: {
            executionState: state,
            riskLevel: synthesis.currentRisk?.level || "low",
            authority,
            dataQuality: synthesis.voiceCalibration?.dataQuality || "sparse",
            phase: synthesis.phase || "observer",
            intensity: synthesis.voiceCalibration?.currentIntensity || 5,
            trigger: triggerType,
          },
        };
      }
      
      console.warn(`Nudge validation failed (attempt ${attempt}):`, validation.violations);
    }
    
    // Fallback to gold standard example
    const fallbackText = this.getFallbackNudge(synthesis, state, authority);
    await this.logGeneration(userId, "nudge", synthesis, fallbackText, { trigger: triggerType });
    
    return {
      text: fallbackText,
      metadata: {
        executionState: state,
        authority,
        riskLevel: "low",
        dataQuality: "sparse",
        phase: synthesis.phase || "observer",
        intensity: 5,
        trigger: triggerType,
      },
    };
  }
  
  /**
   * Generate evening debrief with voice validation and retry.
   */
  async generateDebrief(userId: string, options?: GenerationOptions): Promise<CoachOutput> {
    const synthesis = await memorySynthesis.synthesizeForDebrief(userId);
    const state = this.computeState(synthesis);
    const authority = this.computeAuthority(synthesis);
    
    for (let attempt = 1; attempt <= 2; attempt++) {
      const systemPrompt = this.buildSystemPromptV2("debrief", state, authority, synthesis);
      const userPrompt = this.buildDebriefPrompt(synthesis);
      
      const text = await this.callLLM(systemPrompt, userPrompt, {
        maxTokens: options?.maxTokens || 600,
        temperature: options?.temperature || 0.8,
      });
      
      const validation = validateOutput(text, {
        messageType: "debrief",
        userName: synthesis.userName,
        strictMode: true,
      });
      
      if (validation.passed) {
        await this.logGeneration(userId, "debrief", synthesis, text);
        const questionsAsked = this.extractQuestionsFromResponse(text);
        
        return {
          text: voiceValidator.clean(text, synthesis.userName),
          metadata: {
            executionState: state,
            riskLevel: synthesis.currentRisk?.level || "low",
            authority,
            dataQuality: synthesis.voiceCalibration?.dataQuality || "sparse",
            phase: synthesis.phase || "observer",
            intensity: synthesis.voiceCalibration?.currentIntensity || 5,
            questionsAsked,
          },
        };
      }
      
      console.warn(`Debrief validation failed (attempt ${attempt}):`, validation.violations);
    }
    
    // Fallback to gold standard example
    const fallbackText = this.getFallbackDebrief(synthesis, state, authority);
    await this.logGeneration(userId, "debrief", synthesis, fallbackText);
    
    return {
      text: fallbackText,
      metadata: {
        executionState: state,
        authority,
        riskLevel: "low",
        dataQuality: "sparse",
        phase: synthesis.phase || "observer",
        intensity: 5,
      },
    };
  }
  
  /**
   * Generate weekly letter with voice validation and retry.
   */
  async generateWeeklyLetter(userId: string, options?: GenerationOptions): Promise<CoachOutput> {
    const synthesis = await memorySynthesis.synthesizeForWeeklyLetter(userId);
    const state = this.computeState(synthesis);
    const authority = this.computeAuthority(synthesis);
    
    for (let attempt = 1; attempt <= 2; attempt++) {
      const systemPrompt = this.buildSystemPromptV2("letter", state, authority, synthesis);
      const userPrompt = this.buildWeeklyLetterPrompt(synthesis);
      
      const text = await this.callLLM(systemPrompt, userPrompt, {
        maxTokens: options?.maxTokens || 1000,
        temperature: options?.temperature || 0.85,
      });
      
      const validation = validateOutput(text, {
        messageType: "letter",
        userName: synthesis.userName,
        strictMode: false, // Letters are long-form, less strict
      });
      
      if (validation.passed) {
        await this.logGeneration(userId, "letter", synthesis, text);
        
        return {
          text: voiceValidator.clean(text, synthesis.userName),
          metadata: {
            executionState: state,
            riskLevel: synthesis.currentRisk?.level || "low",
            authority,
            dataQuality: synthesis.voiceCalibration?.dataQuality || "sparse",
            phase: synthesis.phase || "observer",
            intensity: synthesis.voiceCalibration?.currentIntensity || 5,
          },
        };
      }
      
      console.warn(`Weekly letter validation failed (attempt ${attempt}):`, validation.violations);
    }
    
    // Fallback to gold standard example
    const fallbackText = this.getFallbackLetter(synthesis, state, authority);
    await this.logGeneration(userId, "letter", synthesis, fallbackText);
    
    return {
      text: fallbackText,
      metadata: {
        executionState: state,
        authority,
        riskLevel: "low",
        dataQuality: "sparse",
        phase: synthesis.phase || "observer",
        intensity: 5,
      },
    };
  }
  
  /**
   * Generate chat response.
   */
  async generateChatResponse(
    userId: string,
    userMessage: string,
    conversationHistory: Array<{ role: string; content: string }>,
    options?: GenerationOptions
  ): Promise<CoachOutput> {
    const synthesis = await memorySynthesis.synthesizeForChat(userId, conversationHistory);
    
    const systemPrompt = this.buildSystemPrompt(synthesis.voiceCalibration, synthesis.phase);
    const userPrompt = this.buildChatPrompt(synthesis, userMessage);
    
    // Build messages array with history
    const messages = [
      { role: "system" as const, content: systemPrompt },
      ...conversationHistory.slice(-10).map(m => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      })),
      { role: "user" as const, content: userPrompt },
    ];
    
    const text = await this.callLLMWithMessages(messages, {
      maxTokens: options?.maxTokens || 500,
      temperature: options?.temperature || 0.8,
    });
    
    // Learn from the user's message
    await this.learnFromConversation(userId, userMessage);
    
    // Log the generation
    await this.logGeneration(userId, "chat", synthesis, text);
    
    return {
      text,
      metadata: {
        executionState: synthesis.executionState,
        riskLevel: synthesis.currentRisk.level,
        authority: synthesis.voiceCalibration.authority,
        dataQuality: synthesis.voiceCalibration.dataQuality,
        phase: synthesis.phase,
        intensity: synthesis.voiceCalibration.currentIntensity,
      },
    };
  }
  
  // ---------------------------------------------------------------------------
  // PROMPT BUILDERS
  // ---------------------------------------------------------------------------
  
  private buildSystemPrompt(voice: VoiceCalibration, phase: string): string {
    const executionVoice = EXECUTION_STATE_VOICES.MIDDLE; // Default, will be overridden
    const authorityVoice = AUTHORITY_VOICES[voice.authority] || AUTHORITY_VOICES.humble;
    const phaseVoice = PHASE_VOICES[phase as keyof typeof PHASE_VOICES] || PHASE_VOICES.observer;
    
    return `${CORE_IDENTITY}

---
CURRENT AUTHORITY LEVEL: ${voice.authority.toUpperCase()}
${authorityVoice}

---
CURRENT PHASE: ${phase.toUpperCase()}
${phaseVoice}

---
VOICE CALIBRATION:
- Data quality: ${voice.dataQuality}
- Max intensity allowed: ${voice.maxIntensity}/10
- Current intensity: ${voice.currentIntensity}/10
- Approach: ${voice.approachStyle}
- Requires soft landing: ${voice.requiresSoftLanding}

${voice.avoidPhrases.length > 0 ? `AVOID these phrases: "${voice.avoidPhrases.join('", "')}"` : ""}
${voice.preferPhrases.length > 0 ? `PREFER these phrases: "${voice.preferPhrases.join('", "')}"` : ""}

---
PHASE-SPECIFIC TONE:
${voice.phaseTone}`;
  }
  
  private buildBriefPrompt(synthesis: BriefSynthesis): string {
    const dataContext = this.buildDataContext(synthesis);
    const questionGuidance = this.getQuestionGuidance(synthesis.questionFocus);
    const reflectionsContext = this.buildReflectionsContext(synthesis);
    
    return `Generate a morning brief for ${synthesis.userName}.

${dataContext}

YESTERDAY'S PERFORMANCE:
- Completed: ${synthesis.yesterdayPerformance.completed}
- Missed: ${synthesis.yesterdayPerformance.missed}
- Rate: ${synthesis.yesterdayPerformance.rate}%
${synthesis.yesterdayPerformance.highlight ? `- Highlight: ${synthesis.yesterdayPerformance.highlight}` : ""}

TODAY'S FOCUS:
- Priority habits: ${synthesis.todayFocus.priorityHabits.join(", ") || "None identified"}
- Drift windows to watch: ${synthesis.todayFocus.driftWindowsToday.join(", ") || "None identified"}
- Streaks to protect: ${synthesis.todayFocus.streaksToProtect.join(", ") || "None"}

${synthesis.pendingCommitments.length > 0 ? `PENDING COMMITMENTS:
${synthesis.pendingCommitments.map(c => `- "${c.text}" (made ${this.formatTimeAgo(c.madeAt)})`).join("\n")}` : ""}

${synthesis.earnedTruths.length > 0 ? `EARNED TRUTHS (use these):
${synthesis.earnedTruths.slice(0, 3).map(t => `- ${t.statement}`).join("\n")}` : ""}

${synthesis.hypotheses.length > 0 ? `HYPOTHESES (probe if relevant):
${synthesis.hypotheses.filter(h => h.shouldProbe).slice(0, 2).map(h => `- ${h.statement}`).join("\n")}` : ""}

${reflectionsContext}

---
FORMAT:
2-3 paragraphs maximum.
End with ONE powerful question.

${questionGuidance}

---
ANTI-GENERIC CHECKLIST:
□ Did I reference at least 2 specific data points?
□ Did I avoid "You've got this" and similar clichés?
□ Is my question specific to THIS user's situation?
□ Would this message make sense for anyone else? (It shouldn't)
${synthesis.pastReflections.length > 0 ? `□ Did I reference something they told me? (You should!)` : ""}`;
  }
  
  private buildNudgePrompt(synthesis: NudgeSynthesis): string {
    return `Generate a nudge for ${synthesis.userName}.

TRIGGER: ${synthesis.trigger.type}
REASON: ${synthesis.trigger.reason}
SEVERITY: ${synthesis.trigger.severity}/5
URGENCY: ${synthesis.urgency}

${synthesis.atStake ? `AT STAKE: ${synthesis.atStake}` : ""}
${synthesis.relevantPattern ? `RELEVANT PATTERN: ${synthesis.relevantPattern}` : ""}

RECOMMENDED ACTION: ${synthesis.recommendedAction}

CURRENT STATE:
- Execution: ${synthesis.executionState}
- Risk level: ${synthesis.currentRisk.level}
- Days since last action: ${synthesis.recentData.daysSinceLastAction}

${synthesis.recurringExcuses.length > 0 ? `WATCH FOR EXCUSES:
${synthesis.recurringExcuses.slice(0, 2).map(e => `- "${e.phrase}"`).join("\n")}` : ""}

${synthesis.timeWasters.length > 0 ? `KNOWN TIME WASTERS: ${synthesis.timeWasters.join(", ")}` : ""}

---
FORMAT:
2-4 sentences maximum.
One clear action OR one pointed question.
No fluff.

---
INTENSITY: ${synthesis.voiceCalibration.currentIntensity}/10
${synthesis.voiceCalibration.requiresSoftLanding ? "⚠️ This user needs soft landing — don't pile on" : ""}`;
  }
  
  private buildDebriefPrompt(synthesis: DebriefSynthesis): string {
    const dataContext = this.buildDataContext(synthesis);
    const reflectionsContext = this.buildReflectionsContext(synthesis);
    
    return `Generate an evening debrief for ${synthesis.userName}.

${dataContext}

TODAY'S ACTUAL PERFORMANCE:
- Completed: ${synthesis.todayActual.completed.map(h => h.title).join(", ") || "None"}
- Missed: ${synthesis.todayActual.missed.map(h => h.title).join(", ") || "None"}
- Completion rate: ${synthesis.todayActual.completionRate}%
${synthesis.todayActual.bestMoment ? `- Best moment: ${synthesis.todayActual.bestMoment}` : ""}
${synthesis.todayActual.hardestMoment ? `- Hardest moment: ${synthesis.todayActual.hardestMoment}` : ""}

INTENTION VS REALITY:
${synthesis.intentionVsReality.aligned ? "✓ Generally aligned with intentions" : `✗ Gap: ${synthesis.intentionVsReality.gap}`}

DRIFT ANALYSIS:
${synthesis.driftAnalysis.driftedAt ? `- Drifted at: ${synthesis.driftAnalysis.driftedAt}` : "- No major drift detected"}
${synthesis.driftAnalysis.driftCause ? `- Possible cause: ${synthesis.driftAnalysis.driftCause}` : ""}
${synthesis.driftAnalysis.recoveredAt ? `- Recovered at: ${synthesis.driftAnalysis.recoveredAt}` : ""}

TOMORROW SETUP:
${synthesis.tomorrowSetup.priorityHabit ? `- Priority: ${synthesis.tomorrowSetup.priorityHabit}` : ""}
${synthesis.tomorrowSetup.riskWindow ? `- Risk window: ${synthesis.tomorrowSetup.riskWindow}` : ""}
${synthesis.tomorrowSetup.commitmentToProbe ? `- Check on: "${synthesis.tomorrowSetup.commitmentToProbe}"` : ""}

${synthesis.activeContradictions.length > 0 ? `CONTRADICTIONS TO ADDRESS:
${synthesis.activeContradictions.slice(0, 1).map(c => `- ${c.description}`).join("\n")}` : ""}

${reflectionsContext}

---
FORMAT:
2-3 paragraphs maximum.
End with 1-2 questions that:
- Help them process what happened today
- Set intention for tomorrow

---
FOCUS:
- What actually happened vs what they intended
- One honest observation about their pattern
- One forward-looking question
${synthesis.pastReflections?.length > 0 ? `- Reference what they've told you before` : ""}`;
  }
  
  private buildWeeklyLetterPrompt(synthesis: WeeklyLetterSynthesis): string {
    return `Generate a weekly letter for ${synthesis.userName}.

WEEK SUMMARY:
- Total completed: ${synthesis.weekSummary.totalCompleted}
- Total missed: ${synthesis.weekSummary.totalMissed}
- Overall rate: ${synthesis.weekSummary.overallRate}%
- Best day: ${synthesis.weekSummary.bestDay}
- Worst day: ${synthesis.weekSummary.worstDay}
- Trend: ${synthesis.weekSummary.trend}

WEEK OVER WEEK:
- This week: ${synthesis.weekOverWeek.thisWeek}%
- Last week: ${synthesis.weekOverWeek.lastWeek}%
- Change: ${synthesis.weekOverWeek.change > 0 ? "+" : ""}${synthesis.weekOverWeek.change}%
- Assessment: ${synthesis.weekOverWeek.changeDescription}

ARC PROGRESS:
- Phase: ${synthesis.phase}
- Days in phase: ${synthesis.daysInPhase}
- Days in system: ${synthesis.daysInSystem}
${synthesis.arcProgress.milestonesThisWeek.length > 0 ? `- Milestones this week: ${synthesis.arcProgress.milestonesThisWeek.join(", ")}` : ""}
${synthesis.arcProgress.nextMilestone ? `- Next milestone: ${synthesis.arcProgress.nextMilestone}` : ""}

${synthesis.truthToDeliver ? `ONE TRUTH TO DELIVER:
"${synthesis.truthToDeliver}"` : ""}

${synthesis.nextWeekFocus ? `NEXT WEEK FOCUS:
${synthesis.nextWeekFocus}` : ""}

${synthesis.earnedTruths.length > 0 ? `EARNED TRUTHS:
${synthesis.earnedTruths.slice(0, 4).map(t => `- ${t.statement}`).join("\n")}` : ""}

---
FORMAT:
3-4 paragraphs.
Structure:
1. Acknowledge the week (specific numbers, not vague praise)
2. One pattern or truth they need to hear
3. The bigger arc — where they are in their journey
4. One focus for next week + one question

---
TONE:
This is the weekly zoom-out. More philosophical than daily messages.
Reference their journey over time, not just this week.
Speak to who they're becoming.`;
  }
  
  private buildChatPrompt(synthesis: ChatSynthesis, userMessage: string): string {
    const dataContext = this.buildDataContext(synthesis);
    
    return `${dataContext}

CONVERSATION CONTEXT:
- Emotional tone: ${synthesis.conversationContext.emotionalTone}
${synthesis.conversationContext.topicThread ? `- Topic thread: ${synthesis.conversationContext.topicThread}` : ""}

${synthesis.curiosities.length > 0 ? `THINGS TO BE CURIOUS ABOUT:
${synthesis.curiosities.slice(0, 2).map(c => `- ${c}`).join("\n")}` : ""}

${synthesis.patternsToSurface.length > 0 ? `PATTERNS TO POTENTIALLY SURFACE:
${synthesis.patternsToSurface.slice(0, 2).map(p => `- ${p}`).join("\n")}` : ""}

${synthesis.commitmentsToCheck.length > 0 ? `COMMITMENTS TO CHECK ON:
${synthesis.commitmentsToCheck.slice(0, 2).map(c => `- "${c.text}"`).join("\n")}` : ""}

${synthesis.fullPsychology.recurringExcuses.length > 0 ? `RECURRING EXCUSES:
${synthesis.fullPsychology.recurringExcuses.slice(0, 3).map(e => `- "${e.phrase}" (used ${e.frequency}x)`).join("\n")}` : ""}

${synthesis.fullPsychology.limitingNarratives.length > 0 ? `LIMITING NARRATIVES:
${synthesis.fullPsychology.limitingNarratives.slice(0, 2).map(n => `- "${n.narrative}"`).join("\n")}` : ""}

---
USER'S MESSAGE:
"${userMessage}"

---
RESPOND AS FUTURE-YOU:
- Be direct but warm
- Reference specific data when relevant
- If they're making excuses, name it (gently if shame-sensitive)
- If they're asking for advice, give ONE clear action
- If they're reflecting, go deeper with a question
- Never generic — always specific to THEM`;
  }
  
  // ---------------------------------------------------------------------------
  // HELPER FUNCTIONS
  // ---------------------------------------------------------------------------
  
  private buildDataContext(synthesis: BriefSynthesis | NudgeSynthesis | DebriefSynthesis | ChatSynthesis | WeeklyLetterSynthesis): string {
    return `USER CONTEXT:
Name: ${synthesis.userName}
Phase: ${synthesis.phase} (day ${synthesis.daysInPhase})
Days in system: ${synthesis.daysInSystem}
Execution state: ${synthesis.executionState}
Risk level: ${synthesis.currentRisk.level}
${synthesis.purpose ? `Purpose: "${synthesis.purpose}"` : "Purpose: Not yet discovered"}
${synthesis.values.length > 0 ? `Values: ${synthesis.values.join(", ")}` : ""}

RECENT PERFORMANCE:
- Today: ${synthesis.recentData.today.completedCount}/${synthesis.recentData.today.completedCount + synthesis.recentData.today.missedCount + synthesis.recentData.today.pendingCount} completed
- This week: ${synthesis.recentData.week.rate}% (${synthesis.recentData.week.trend})
- Last engagement: ${synthesis.recentData.lastEngagement}
${synthesis.recentData.activeStreaks.length > 0 ? `- Active streaks: ${synthesis.recentData.activeStreaks.map(s => `${s.habitTitle} (${s.days}d)`).join(", ")}` : "- No active streaks"}

${synthesis.activeTriggerWarning ? `⚠️ ACTIVE WARNING: ${synthesis.activeTriggerWarning.chainName} pattern detected (stage ${synthesis.activeTriggerWarning.currentStage}/${synthesis.activeTriggerWarning.totalStages})` : ""}`;
  }
  
  /**
   * Build context from past reflections for memory loop.
   * This allows AI to say "You said last week..." or "You told me..."
   */
  private buildReflectionsContext(synthesis: any): string {
    if (!synthesis.pastReflections || synthesis.pastReflections.length === 0) {
      return "";
    }
    
    const reflections = synthesis.pastReflections.slice(0, 3).map((r: any) => {
      const timeAgo = this.formatDayKeyToTimeAgo(r.dayKey);
      return `- "${r.text}" (${timeAgo}, from ${r.source === "morning_brief" ? "morning brief" : "evening debrief"})`;
    });
    
    return `PAST REFLECTIONS (use these to show you remember):
${reflections.join("\n")}

MEMORY LOOP GUIDANCE:
- Reference what they've told you: "You said..." or "You mentioned..."
- Connect patterns: "Last week you said X, and today..."
- Show continuity: "Remember when you told me..."`;
  }
  
  private formatDayKeyToTimeAgo(dayKey: string): string {
    try {
      const date = new Date(dayKey);
      const now = new Date();
      const diffDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));
      
      if (diffDays === 0) return "today";
      if (diffDays === 1) return "yesterday";
      if (diffDays < 7) return `${diffDays} days ago`;
      if (diffDays < 14) return "last week";
      return `${Math.floor(diffDays / 7)} weeks ago`;
    } catch {
      return "recently";
    }
  }
  
  private getQuestionGuidance(focus: BriefSynthesis["questionFocus"]): string {
    switch (focus) {
      case "extract_fear":
        return `QUESTION FOCUS: Extract fear
Ask about what they're afraid of, what's holding them back, what they're avoiding.
Example: "What are you most afraid will happen if you don't show up today?"`;
      
      case "confront_pattern":
        return `QUESTION FOCUS: Confront pattern
Point out the contradiction and ask them to explain it.
Example: "You say X is important, but you've missed it 5 of 7 days. What's really going on?"`;
      
      case "clarify_intention":
        return `QUESTION FOCUS: Clarify intention
Help them get specific about what they want and why.
Example: "What would completing today's habits prove to yourself?"`;
      
      case "probe_excuse":
        return `QUESTION FOCUS: Probe excuse
They have recurring excuses. Dig into them.
Example: "You've said 'I didn't have time' 4 times this week. What did you have time for instead?"`;
      
      case "celebrate_progress":
        return `QUESTION FOCUS: Celebrate and push deeper
Acknowledge their progress, then ask what's next.
Example: "14 days straight. You've proven you can do this. What's the next level look like?"`;
    }
  }
  
  private formatTimeAgo(date: Date): string {
    const now = Date.now();
    const then = new Date(date).getTime();
    const diffHours = Math.floor((now - then) / 3600000);
    
    if (diffHours < 1) return "just now";
    if (diffHours < 24) return `${diffHours} hours ago`;
    if (diffHours < 48) return "yesterday";
    return `${Math.floor(diffHours / 24)} days ago`;
  }
  
  private extractQuestionsFromResponse(text: string): string[] {
    const questions: string[] = [];
    const sentences = text.split(/[.!?]+/);
    
    for (const sentence of sentences) {
      if (sentence.includes("?")) {
        questions.push(sentence.trim());
      }
    }
    
    return questions;
  }
  
  // ---------------------------------------------------------------------------
  // LEARNING FUNCTIONS
  // ---------------------------------------------------------------------------
  
  private async learnFromConversation(userId: string, userMessage: string): Promise<void> {
    const message = userMessage.toLowerCase();
    
    // Detect excuses
    const excusePatterns = [
      { pattern: /didn'?t have time/i, phrase: "didn't have time" },
      { pattern: /too tired/i, phrase: "too tired" },
      { pattern: /too busy/i, phrase: "too busy" },
      { pattern: /forgot/i, phrase: "forgot" },
      { pattern: /wasn'?t in the mood/i, phrase: "wasn't in the mood" },
      { pattern: /didn'?t feel like it/i, phrase: "didn't feel like it" },
      { pattern: /had too much/i, phrase: "had too much going on" },
      { pattern: /something came up/i, phrase: "something came up" },
      { pattern: /got distracted/i, phrase: "got distracted" },
      { pattern: /couldn'?t focus/i, phrase: "couldn't focus" },
    ];
    
    for (const { pattern, phrase } of excusePatterns) {
      if (pattern.test(message)) {
        await deepUserModel.addExcuse(userId, phrase, false);
      }
    }
    
    // Detect limiting narratives
    const narrativePatterns = [
      { pattern: /i always fail/i, narrative: "I always fail", sentiment: "limiting" as const },
      { pattern: /i can'?t stay consistent/i, narrative: "I can't stay consistent", sentiment: "limiting" as const },
      { pattern: /this is just who i am/i, narrative: "This is just who I am", sentiment: "limiting" as const },
      { pattern: /i'?m not disciplined/i, narrative: "I'm not disciplined", sentiment: "limiting" as const },
      { pattern: /i never follow through/i, narrative: "I never follow through", sentiment: "limiting" as const },
      { pattern: /i'?m bad at/i, narrative: "I'm bad at this", sentiment: "limiting" as const },
      { pattern: /it'?s too hard/i, narrative: "It's too hard", sentiment: "limiting" as const },
    ];
    
    for (const { pattern, narrative, sentiment } of narrativePatterns) {
      if (pattern.test(message)) {
        await deepUserModel.addNarrative(userId, narrative, sentiment);
      }
    }
    
    // Detect commitments
    const commitmentPatterns = [
      /i'?ll do it (tomorrow|later|tonight|this evening)/i,
      /i promise i'?ll/i,
      /i'?m going to/i,
      /starting (tomorrow|monday|next week)/i,
    ];
    
    for (const pattern of commitmentPatterns) {
      const match = message.match(pattern);
      if (match) {
        await deepUserModel.addCommitment(userId, {
          text: userMessage.slice(0, 200),
          extractedAction: match[0],
          extractedTime: match[1] || null,
          madeAt: new Date(),
          madeIn: "chat",
          dueBy: this.parseCommitmentDueDate(match[1] || "tomorrow"),
          wasExplicit: message.includes("promise"),
          followUpSent: false,
        });
      }
    }
  }
  
  private parseCommitmentDueDate(timePhrase: string): Date {
    const now = new Date();
    
    switch (timePhrase.toLowerCase()) {
      case "tomorrow":
        return new Date(now.getTime() + 24 * 3600000);
      case "tonight":
      case "this evening":
        const tonight = new Date(now);
        tonight.setHours(21, 0, 0, 0);
        return tonight;
      case "monday":
        const monday = new Date(now);
        monday.setDate(monday.getDate() + ((1 + 7 - monday.getDay()) % 7));
        return monday;
      case "next week":
        return new Date(now.getTime() + 7 * 24 * 3600000);
      default:
        return new Date(now.getTime() + 24 * 3600000);
    }
  }
  
  // ---------------------------------------------------------------------------
  // LOGGING
  // ---------------------------------------------------------------------------
  
  private async logGeneration(
    userId: string,
    type: "brief" | "nudge" | "debrief" | "letter" | "chat",
    synthesis: BriefSynthesis | NudgeSynthesis | DebriefSynthesis | ChatSynthesis | WeeklyLetterSynthesis,
    text: string,
    extra?: Record<string, any>
  ): Promise<void> {
    try {
      await prisma.event.create({
        data: {
          userId,
          type: `coach_${type}`,
          payload: {
            text: text.slice(0, 500), // Truncate for storage
            executionState: synthesis.executionState,
            riskLevel: synthesis.currentRisk.level,
            authority: synthesis.voiceCalibration.authority,
            dataQuality: synthesis.voiceCalibration.dataQuality,
            phase: synthesis.phase,
            intensity: synthesis.voiceCalibration.currentIntensity,
            modelConfidence: synthesis.modelConfidence,
            ...extra,
          },
        },
      });
    } catch (error) {
      console.error(`Failed to log ${type} generation:`, error);
    }
  }
  
  // ---------------------------------------------------------------------------
  // LLM CALLS
  // ---------------------------------------------------------------------------
  
  private async callLLM(
    systemPrompt: string,
    userPrompt: string,
    options: { maxTokens: number; temperature: number }
  ): Promise<string> {
    const openai = getOpenAIClient();
    
    if (!openai) {
      return this.getFallbackResponse("brief");
    }
    
    try {
      const completion = await openai.chat.completions.create({
        model: OPENAI_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        max_tokens: options.maxTokens,
        temperature: options.temperature,
      });
      
      return completion.choices[0]?.message?.content || this.getFallbackResponse("brief");
    } catch (error) {
      console.error("LLM call failed:", error);
      return this.getFallbackResponse("brief");
    }
  }
  
  private async callLLMWithMessages(
    messages: Array<{ role: "system" | "user" | "assistant"; content: string }>,
    options: { maxTokens: number; temperature: number }
  ): Promise<string> {
    const openai = getOpenAIClient();
    
    if (!openai) {
      return this.getFallbackResponse("chat");
    }
    
    try {
      const completion = await openai.chat.completions.create({
        model: OPENAI_MODEL,
        messages,
        max_tokens: options.maxTokens,
        temperature: options.temperature,
      });
      
      return completion.choices[0]?.message?.content || this.getFallbackResponse("chat");
    } catch (error) {
      console.error("LLM call failed:", error);
      return this.getFallbackResponse("chat");
    }
  }
  
  private getFallbackResponse(type: string): string {
    switch (type) {
      case "brief":
        return "Good morning. Today is a fresh start. What's the one thing you won't let slip today?";
      case "nudge":
        return "Check in with yourself. What needs doing right now?";
      case "debrief":
        return "The day is ending. What did you learn about yourself today?";
      case "letter":
        return "Another week behind you. What pattern do you want to change next week?";
      case "chat":
        return "I'm here. What's on your mind?";
      default:
        return "What's on your mind?";
    }
  }
}

// =============================================================================
// EXPORT SINGLETON
// =============================================================================

export const coachEngine = new CoachEngineService();