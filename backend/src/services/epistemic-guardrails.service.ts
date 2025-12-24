// =============================================================================
// EPISTEMIC GUARDRAILS SERVICE
// =============================================================================
// ⚠️ CRITICAL: This service ensures the AI NEVER makes claims it can't back up.
//
// The #1 trust killer is when the AI says things like:
// - "I've noticed you tend to avoid mornings" (based on 2 days of data)
// - "You've been silent for 4 hours" (no timestamp data exists)
// - "Your pattern of avoidance" (invented pattern)
//
// This service:
// 1. Builds an EpistemicContext from real data
// 2. Determines what claims are ALLOWED based on data quality
// 3. Injects strict rules into prompts
// 4. Validates output BEFORE sending to user
// 5. Strips/rewrites any claims that violate epistemic rules
// =============================================================================

import { prisma } from "../utils/db";

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

export interface EpistemicContext {
  // User timeline
  daysInSystem: number;
  phase: "observer" | "architect" | "oracle";
  
  // Data quality assessment
  dataQuality: "none" | "sparse" | "developing" | "rich" | "comprehensive";
  totalEvents: number;
  totalCompletions: number;
  totalReflections: number;
  
  // Permission flags - what can the AI claim?
  canClaimPatterns: boolean;
  canClaimTiming: boolean;
  canClaimPredictions: boolean;
  canClaimHistory: boolean;
  canUseDirectConfrontation: boolean;
  
  // What we ACTUALLY know
  verifiedFacts: VerifiedFact[];
  
  // Voice calibration
  authority: "humble" | "growing" | "earned" | "deep";
  maxConfidenceLevel: "tentative" | "observational" | "confident" | "certain";
  
  // Prompt injection
  epistemicRules: string;
  bannedClaims: string[];
}

export interface VerifiedFact {
  type: "completion" | "streak" | "miss" | "reflection" | "pattern";
  content: string;
  confidence: "verified" | "observed" | "inferred";
  evidence: string;
}

// =============================================================================
// BANNED CLAIM PATTERNS BY PHASE
// =============================================================================

const OBSERVER_BANNED_PATTERNS = [
  /I've noticed you (tend to|always|never|usually)/gi,
  /Your pattern (shows|suggests|indicates|of)/gi,
  /You (always|never|typically|usually|consistently)/gi,
  /\d+ hours? (of silence|ago|since|without)/gi,
  /I remember when you/gi,
  /You told me (that|about|when)/gi,
  /Based on your history/gi,
  /Your (typical|usual|normal) (behavior|pattern|approach)/gi,
  /I've seen you do this before/gi,
  /This is (a pattern|becoming a pattern|your pattern)/gi,
  /You've been (avoiding|struggling|failing|slipping)/gi,
  /Your track record (shows|suggests)/gi,
];

const ARCHITECT_BANNED_PATTERNS = [
  /You (always|never) /gi,
  /\d+ hours? (of silence|ago)/gi,
  /I remember when you/gi,
  /You told me that/gi,
];

// =============================================================================
// EPISTEMIC RULES BY PHASE
// =============================================================================

const OBSERVER_EPISTEMIC_RULES = `
## EPISTEMIC RULES - OBSERVER PHASE (Days 1-7)
⚠️ YOU ARE LEARNING, NOT KNOWING. VIOLATING THESE RULES DESTROYS USER TRUST.

### ABSOLUTELY FORBIDDEN:
- "I've noticed you tend to..." → You haven't observed long enough
- "Your pattern shows..." → You don't have pattern data yet
- "You always/never..." → You have no basis for generalizations
- "X hours of silence..." → You don't have reliable timing data
- "I remember when you..." → You have no history to remember
- Any claim about their "typical" behavior
- Any prediction about what they'll do

### WHAT YOU CAN SAY:
- Acknowledge TODAY's actions only: "You completed X today"
- Ask discovery questions: "What usually gets in your way?"
- Express curiosity: "I'm learning how you move"
- Be honest about limits: "I don't know your patterns yet"
- Celebrate present actions: "That's a win right there"

### REQUIRED HUMILITY PHRASES:
- "I'm still learning how you operate..."
- "Early days - tell me more about..."
- "I don't have the full picture yet, but..."
- "This is day [X] - I'm watching and learning..."

### EXAMPLE GOOD MESSAGE:
"Day 3. I'm still getting to know you.
You knocked out Morning Workout today - that's a concrete win.
I don't know your patterns yet, that's what this week is for.
Question: What usually makes mornings hard for you?"

### EXAMPLE BAD MESSAGE (NEVER DO THIS):
"I've noticed you struggle with consistency in the mornings.
Your pattern of avoidance is becoming clear.
You've been silent for 4 hours - this is typical behavior."
`;

const ARCHITECT_EPISTEMIC_RULES = `
## EPISTEMIC RULES - ARCHITECT PHASE (Days 8-30)
You can make TENTATIVE observations, but must cite evidence.

### FORBIDDEN:
- Certainty without evidence: "You always do X"
- Specific timing claims without data: "4 hours ago"
- Invented memories: "You told me that..."
- Pattern claims without numbers: "Your pattern of..."

### ALLOWED:
- Observations with evidence: "In the past 7 days, you've completed 5/7 morning habits"
- Tentative patterns: "I'm starting to see that Wednesdays are harder for you"
- Questions to confirm: "Does this match how you see it?"
- Soft challenges: "The data suggests X - what's your read?"

### REQUIRED EVIDENCE FORMAT:
When making any claim about patterns, you MUST cite:
- Time range: "Over the past X days..."
- Specific numbers: "You've done X out of Y..."
- Tentative language: "It seems like...", "The pattern suggests..."

### EXAMPLE GOOD MESSAGE:
"Week 2. I'm starting to see how you move.
Over the past 7 days: 71% completion rate. Morning Workout: 6/7 days.
Wednesdays look harder - you've missed 2 of the last 3.
What happens on Wednesdays?"

### EXAMPLE BAD MESSAGE:
"You always struggle on Wednesdays. This is your pattern.
I've noticed you avoid the hard stuff when you're stressed."
`;

const ORACLE_EPISTEMIC_RULES = `
## EPISTEMIC RULES - ORACLE PHASE (Days 31+)
You've earned authority through observation. Speak with confidence but stay grounded.

### ALLOWED:
- Direct pattern calls: "You slip on Wednesdays after skipping Monday"
- Historical references: "Three weeks ago you broke a 12-day streak after..."
- Confident observations: "This is avoidance. I've seen it before."
- Predictions: "If you skip today, tomorrow gets harder"

### STILL FORBIDDEN:
- Inventing specific times without data
- Claiming memories of conversations that didn't happen
- Fabricating numbers or statistics
- Emotional claims without behavioral evidence

### YOUR POWER NOW:
- Use their own words back to them
- Reference specific events from their history
- Call out contradictions directly
- Speak to who they're becoming, not just what they're doing
`;

// =============================================================================
// SERVICE CLASS
// =============================================================================

class EpistemicGuardrailsService {
  
  /**
   * Build epistemic context from user data
   */
  async buildContext(userId: string): Promise<EpistemicContext> {
    // Get real data counts
    const [user, eventCount, completionCount, reflectionCount] = await Promise.all([
      prisma.user.findUnique({ where: { id: userId } }),
      prisma.event.count({ where: { userId } }),
      prisma.completion.count({ where: { userId } }),
      prisma.event.count({ where: { userId, type: "reflection_answer" } }),
    ]);
    
    // Calculate days in system
    const createdAt = user?.createdAt || new Date();
    const daysInSystem = Math.floor((Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24));
    
    // Determine phase
    let phase: EpistemicContext["phase"] = "observer";
    if (daysInSystem >= 8 && daysInSystem < 31) phase = "architect";
    if (daysInSystem >= 31) phase = "oracle";
    
    // Assess data quality
    const totalEvents = eventCount + completionCount;
    let dataQuality: EpistemicContext["dataQuality"] = "none";
    if (totalEvents > 0) dataQuality = "sparse";
    if (totalEvents >= 15) dataQuality = "developing";
    if (totalEvents >= 50) dataQuality = "rich";
    if (totalEvents >= 100 && reflectionCount >= 10) dataQuality = "comprehensive";
    
    // Determine permissions based on phase AND data quality
    const canClaimPatterns = phase !== "observer" && dataQuality !== "sparse" && dataQuality !== "none";
    const canClaimTiming = totalEvents >= 30; // Need substantial data for timing claims
    const canClaimPredictions = phase === "oracle" && dataQuality === "comprehensive";
    const canClaimHistory = phase !== "observer" && totalEvents >= 20;
    const canUseDirectConfrontation = phase === "oracle" || (phase === "architect" && dataQuality === "rich");
    
    // Determine authority
    let authority: EpistemicContext["authority"] = "humble";
    if (phase === "architect" && dataQuality !== "sparse") authority = "growing";
    if (phase === "architect" && dataQuality === "rich") authority = "earned";
    if (phase === "oracle") authority = dataQuality === "comprehensive" ? "deep" : "earned";
    
    // Determine max confidence level
    let maxConfidenceLevel: EpistemicContext["maxConfidenceLevel"] = "tentative";
    if (phase === "architect") maxConfidenceLevel = "observational";
    if (phase === "oracle" && dataQuality === "rich") maxConfidenceLevel = "confident";
    if (phase === "oracle" && dataQuality === "comprehensive") maxConfidenceLevel = "certain";
    
    // Get verified facts
    const verifiedFacts = await this.getVerifiedFacts(userId, daysInSystem);
    
    // Build epistemic rules string
    let epistemicRules = OBSERVER_EPISTEMIC_RULES;
    if (phase === "architect") epistemicRules = ARCHITECT_EPISTEMIC_RULES;
    if (phase === "oracle") epistemicRules = ORACLE_EPISTEMIC_RULES;
    
    // Add dynamic data to rules
    epistemicRules = epistemicRules.replace(/\[X\]/g, daysInSystem.toString());
    
    // Build banned claims list
    const bannedClaims = this.getBannedClaims(phase, dataQuality);
    
    return {
      daysInSystem,
      phase,
      dataQuality,
      totalEvents: eventCount,
      totalCompletions: completionCount,
      totalReflections: reflectionCount,
      canClaimPatterns,
      canClaimTiming,
      canClaimPredictions,
      canClaimHistory,
      canUseDirectConfrontation,
      verifiedFacts,
      authority,
      maxConfidenceLevel,
      epistemicRules,
      bannedClaims,
    };
  }
  
  /**
   * Get verified facts we can actually claim
   */
  private async getVerifiedFacts(userId: string, daysInSystem: number): Promise<VerifiedFact[]> {
    const facts: VerifiedFact[] = [];
    
    // Get today's completions
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const todayCompletions = await prisma.completion.findMany({
      where: { userId, date: { gte: today }, done: true },
    });
    
    const habits = await prisma.habit.findMany({
      where: { userId },
      select: { id: true, title: true, streak: true },
    });
    
    const habitMap = new Map(habits.map(h => [h.id, h]));
    
    // Add today's completions as verified facts
    for (const c of todayCompletions) {
      const habit = habitMap.get(c.habitId);
      if (habit) {
        facts.push({
          type: "completion",
          content: `Completed "${habit.title}" today`,
          confidence: "verified",
          evidence: `Completion record from ${today.toISOString().split('T')[0]}`,
        });
      }
    }
    
    // Add streak facts
    for (const habit of habits) {
      if (habit.streak >= 3) {
        facts.push({
          type: "streak",
          content: `${habit.streak}-day streak on "${habit.title}"`,
          confidence: "verified",
          evidence: `Streak counter in habit record`,
        });
      }
    }
    
    // Add days in system as verified fact
    facts.push({
      type: "pattern",
      content: `User has been in system for ${daysInSystem} days`,
      confidence: "verified",
      evidence: `User createdAt timestamp`,
    });
    
    return facts;
  }
  
  /**
   * Get list of banned claim phrases for this phase
   */
  private getBannedClaims(phase: EpistemicContext["phase"], dataQuality: EpistemicContext["dataQuality"]): string[] {
    const banned: string[] = [];
    
    if (phase === "observer") {
      banned.push(
        "I've noticed you tend to",
        "Your pattern shows",
        "You always",
        "You never",
        "You typically",
        "You usually",
        "hours of silence",
        "hours ago",
        "I remember when you",
        "You told me",
        "Based on your history",
        "Your typical behavior",
        "I've seen you do this before",
        "This is a pattern",
        "This is becoming a pattern",
        "You've been avoiding",
        "You've been struggling",
        "Your track record",
      );
    }
    
    if (phase === "architect" && dataQuality === "sparse") {
      banned.push(
        "You always",
        "You never",
        "hours ago",
        "I remember when you",
        "You told me that",
      );
    }
    
    return banned;
  }
  
  /**
   * Validate a message before sending - strip/rewrite invalid claims
   */
  validateAndClean(message: string, context: EpistemicContext): { 
    cleaned: string; 
    violations: string[];
    wasModified: boolean;
  } {
    let cleaned = message;
    const violations: string[] = [];
    let wasModified = false;
    
    // Get patterns to check based on phase
    let patterns: RegExp[] = [];
    if (context.phase === "observer") {
      patterns = OBSERVER_BANNED_PATTERNS;
    } else if (context.phase === "architect") {
      patterns = ARCHITECT_BANNED_PATTERNS;
    }
    
    // Check each pattern
    for (const pattern of patterns) {
      const match = cleaned.match(pattern);
      if (match) {
        violations.push(`EPISTEMIC_VIOLATION: "${match[0]}" in ${context.phase} phase`);
        
        // Replace with humble alternative
        cleaned = cleaned.replace(pattern, this.getHumbleReplacement(match[0], context));
        wasModified = true;
      }
    }
    
    // Check for specific hour claims
    if (!context.canClaimTiming) {
      const hourPattern = /(\d+)\s*hours?\s*(of silence|ago|since|without)/gi;
      const hourMatch = cleaned.match(hourPattern);
      if (hourMatch) {
        violations.push(`TIMING_VIOLATION: "${hourMatch[0]}" without timing data`);
        cleaned = cleaned.replace(hourPattern, "recently");
        wasModified = true;
      }
    }
    
    // Log violations for monitoring
    if (violations.length > 0) {
      console.warn(`⚠️ EPISTEMIC VIOLATIONS DETECTED (${context.phase} phase):`, violations);
    }
    
    return { cleaned, violations, wasModified };
  }
  
  /**
   * Get humble replacement phrase for a violation
   */
  private getHumbleReplacement(violation: string, context: EpistemicContext): string {
    const lowerViolation = violation.toLowerCase();
    
    if (lowerViolation.includes("noticed you tend")) {
      return "I'm curious about";
    }
    if (lowerViolation.includes("pattern")) {
      return "I'm starting to observe";
    }
    if (lowerViolation.includes("always") || lowerViolation.includes("never")) {
      return "sometimes you";
    }
    if (lowerViolation.includes("hours")) {
      return "recently";
    }
    if (lowerViolation.includes("remember when")) {
      return "thinking about";
    }
    if (lowerViolation.includes("told me")) {
      return "mentioned";
    }
    
    return "I'm noticing";
  }
  
  /**
   * Inject epistemic rules into a prompt
   */
  injectIntoPrompt(basePrompt: string, context: EpistemicContext): string {
    // Build verified facts section
    const factsSection = context.verifiedFacts.length > 0
      ? `\n\n## VERIFIED FACTS (You CAN reference these):\n${context.verifiedFacts.map(f => `- ${f.content}`).join("\n")}`
      : "\n\n## VERIFIED FACTS: None yet. Ask questions to learn.";
    
    // Build banned claims section
    const bannedSection = context.bannedClaims.length > 0
      ? `\n\n## BANNED CLAIMS (NEVER say these in ${context.phase} phase):\n${context.bannedClaims.map(c => `- "${c}..."`).join("\n")}`
      : "";
    
    // Build permissions section
    const permissions = `
## YOUR EPISTEMIC PERMISSIONS:
- Can claim patterns: ${context.canClaimPatterns ? "YES (with evidence)" : "NO - ask questions instead"}
- Can claim timing: ${context.canClaimTiming ? "YES" : "NO - avoid hour/minute claims"}
- Can make predictions: ${context.canClaimPredictions ? "YES" : "NO - stay observational"}
- Can reference history: ${context.canClaimHistory ? "YES (specific events only)" : "NO - focus on present"}
- Can confront directly: ${context.canUseDirectConfrontation ? "YES" : "NO - stay curious and supportive"}
`;
    
    return `${context.epistemicRules}

${permissions}

${factsSection}

${bannedSection}



---



${basePrompt}`;
  }
}

export const epistemicGuardrails = new EpistemicGuardrailsService();

