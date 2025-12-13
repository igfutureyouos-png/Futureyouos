// =============================================================================
// MEMORY SYNTHESIS SERVICE
// =============================================================================
// Transforms the DeepUserModel into context-specific views optimized for
// each generation type (brief, nudge, debrief, chat, weekly letter).
//
// This is the bridge between raw data and the coach engine prompts.
// Each synthesis method returns exactly what the LLM needs to generate
// a highly personalized, data-grounded message.
// =============================================================================

import { 
    deepUserModel, 
    DeepUserModel,
    UserIdentity,
    UserBehavior,
    UserPatterns,
    UserPsychology,
    UserPredictions,
    UserArc,
    SlipRiskAssessment,
    TriggerChainWarning,
    CommitmentRecord,
    ShameSensitivity,
    RecurringExcuse,
    Contradiction,
  } from "./deep-user-model.service";
  import { prisma } from "../utils/db";
  import { redis } from "../utils/redis";
  import { semanticMemory } from "./semanticMemory.service";
  
  // =============================================================================
  // TYPE DEFINITIONS
  // =============================================================================
  
  // -----------------------------------------------------------------------------
  // Voice Calibration
  // -----------------------------------------------------------------------------
  export interface VoiceCalibration {
    // Data-based authority
    dataQuality: "sparse" | "developing" | "rich" | "comprehensive";
    authority: "humble" | "growing" | "earned" | "deep";
    
    // Risk-based intensity
    maxIntensity: number; // 1-10, from shame sensitivity
    currentIntensity: number; // Adjusted for current state
    
    // Approach
    approachStyle: "challenge" | "support" | "neutral" | "celebration";
    requiresSoftLanding: boolean;
    
    // Phase-specific tone
    phaseTone: string;
    
    // Specific guidance
    avoidPhrases: string[];
    preferPhrases: string[];
  }
  
  // -----------------------------------------------------------------------------
  // Recent Data Snapshot
  // -----------------------------------------------------------------------------
  export interface TodayHabit {
    title: string;
    completed: boolean;
    streak: number;
    scheduledTime: string | null;
  }
  
  export interface RecentDataSnapshot {
    // Today
    today: {
      completions: TodayHabit[];
      completedCount: number;
      missedCount: number;
      pendingCount: number;
      completionRate: number;
    };
    
    // This week
    week: {
      completed: number;
      total: number;
      rate: number;
      trend: "up" | "down" | "stable";
    };
    
    // Active streaks
    activeStreaks: Array<{
      habitTitle: string;
      days: number;
      atRisk: boolean;
    }>;
    
    // Recent wins
    recentWins: string[];
    
    // Last engagement
    lastEngagement: string; // "2 hours ago", "yesterday", etc.
    daysSinceLastAction: number;
  }
  
  // -----------------------------------------------------------------------------
  // Earned Truths & Hypotheses
  // -----------------------------------------------------------------------------
  export interface EarnedTruth {
    statement: string;
    confidence: number;
    evidence: string;
    category: "behavior" | "pattern" | "psychology" | "identity";
  }
  
  export interface Hypothesis {
    statement: string;
    confidence: number;
    basis: string;
    shouldProbe: boolean;
  }
  
  // -----------------------------------------------------------------------------
  // Base Memory Synthesis (shared across all types)
  // -----------------------------------------------------------------------------
  export interface BaseMemorySynthesis {
    // User reference
    userId: string;
    userName: string;
    
    // Current state
    executionState: "ON_TRACK" | "MIDDLE" | "SLIP";
    executionEvidence: string[];
    
    // Risk assessment
    currentRisk: SlipRiskAssessment;
    
    // Active warnings
    activeTriggerWarning: TriggerChainWarning | null;
    
    // Voice calibration
    voiceCalibration: VoiceCalibration;
    
    // What we know vs don't know
    earnedTruths: EarnedTruth[];
    hypotheses: Hypothesis[];
    unknowns: string[];
    
    // Contradictions to potentially address
    activeContradictions: Contradiction[];
    
    // Recent data
    recentData: RecentDataSnapshot;
    
    // Phase & arc
    phase: "observer" | "architect" | "oracle";
    daysInPhase: number;
    daysInSystem: number;
    
    // Identity anchors
    purpose: string | null;
    values: string[];
    
    // Psychology (for voice calibration)
    shameSensitivity: ShameSensitivity;
    recurringExcuses: RecurringExcuse[];
    timeWasters: string[];
    
    // Model confidence
    modelConfidence: "insufficient" | "low" | "medium" | "high";
    
    // Past reflections from Chroma (for referencing)
    pastReflections: Array<{
      text: string;
      dayKey: string;
      source: string;
    }>;
    reflectionCount: number;
  }
  
  // -----------------------------------------------------------------------------
  // Brief-Specific Synthesis
  // -----------------------------------------------------------------------------
  export interface BriefSynthesis extends BaseMemorySynthesis {
    type: "brief";
    
    // Morning-specific context
    yesterdayPerformance: {
      completed: number;
      missed: number;
      rate: number;
      highlight: string | null;
    };
    
    // What to focus on today
    todayFocus: {
      priorityHabits: string[];
      driftWindowsToday: string[];
      streaksToProtect: string[];
    };
    
    // Pending commitments from yesterday
    pendingCommitments: CommitmentRecord[];
    
    // Question focus (what should the brief ask about?)
    questionFocus: "extract_fear" | "confront_pattern" | "clarify_intention" | "probe_excuse" | "celebrate_progress";
  }
  
  // -----------------------------------------------------------------------------
  // Nudge-Specific Synthesis
  // -----------------------------------------------------------------------------
  export interface NudgeSynthesis extends BaseMemorySynthesis {
    type: "nudge";
    
    // Trigger context
    trigger: {
      type: string;
      reason: string;
      severity: number; // 1-5
      habitContext: string | null;
    };
    
    // Urgency
    urgency: "low" | "medium" | "high" | "critical";
    
    // What's at stake
    atStake: string | null; // "7-day meditation streak", "afternoon deep work block"
    
    // Recent pattern that led here
    relevantPattern: string | null;
    
    // Recommended action
    recommendedAction: string;
  }
  
  // -----------------------------------------------------------------------------
  // Debrief-Specific Synthesis
  // -----------------------------------------------------------------------------
  export interface DebriefSynthesis extends BaseMemorySynthesis {
    type: "debrief";
    
    // Today's actual performance
    todayActual: {
      completed: TodayHabit[];
      missed: TodayHabit[];
      completionRate: number;
      bestMoment: string | null;
      hardestMoment: string | null;
    };
    
    // Comparison to intention
    intentionVsReality: {
      aligned: boolean;
      gap: string | null;
    };
    
    // Drift analysis
    driftAnalysis: {
      driftedAt: string | null;
      driftCause: string | null;
      recoveredAt: string | null;
    };
    
    // Tomorrow setup
    tomorrowSetup: {
      priorityHabit: string | null;
      riskWindow: string | null;
      commitmentToProbe: string | null;
    };
  }
  
  // -----------------------------------------------------------------------------
  // Chat-Specific Synthesis
  // -----------------------------------------------------------------------------
  export interface ChatSynthesis extends BaseMemorySynthesis {
    type: "chat";
    
    // Conversation context
    conversationContext: {
      recentMessages: Array<{ role: string; content: string }>;
      emotionalTone: string;
      topicThread: string | null;
    };
    
    // What we're curious about
    curiosities: string[];
    
    // Patterns to potentially surface
    patternsToSurface: string[];
    
    // Commitments to check on
    commitmentsToCheck: CommitmentRecord[];
    
    // Full psychology for deep conversation
    fullPsychology: UserPsychology;
  }
  
  // -----------------------------------------------------------------------------
  // Weekly Letter-Specific Synthesis
  // -----------------------------------------------------------------------------
  export interface WeeklyLetterSynthesis extends BaseMemorySynthesis {
    type: "weekly_letter";
    
    // Week-level view
    weekSummary: {
      totalCompleted: number;
      totalMissed: number;
      overallRate: number;
      bestDay: string;
      worstDay: string;
      trend: "improving" | "declining" | "stable";
    };
    
    // Comparison to previous weeks
    weekOverWeek: {
      thisWeek: number;
      lastWeek: number;
      change: number;
      changeDescription: string;
    };
    
    // Arc progress
    arcProgress: {
      milestonesThisWeek: string[];
      nextMilestone: string | null;
      narrativeShift: string | null;
    };
    
    // One truth they need to hear
    truthToDeliver: string | null;
    
    // Focus for next week
    nextWeekFocus: string | null;
  }
  
  // Union type
  export type MemorySynthesis = 
    | BriefSynthesis 
    | NudgeSynthesis 
    | DebriefSynthesis 
    | ChatSynthesis 
    | WeeklyLetterSynthesis;
  
  // =============================================================================
  // SERVICE CLASS
  // =============================================================================
  
  class MemorySynthesisService {
    
    // ---------------------------------------------------------------------------
    // MAIN SYNTHESIS FUNCTIONS
    // ---------------------------------------------------------------------------
    
    /**
     * Synthesize context for morning brief generation.
     */
    async synthesizeForBrief(userId: string): Promise<BriefSynthesis> {
      const model = await deepUserModel.buildDeepUserModel(userId);
      const base = await this.buildBaseSynthesis(model);
      
      // Get yesterday's performance
      const yesterdayPerformance = await this.getYesterdayPerformance(userId, model);
      
      // Determine today's focus
      const todayFocus = this.determineTodayFocus(model);
      
      // Get pending commitments
      const pendingCommitments = model.learned?.commitments?.filter(
        c => c.status === "pending"
      ) || [];
      
      // Determine question focus
      const questionFocus = this.determineQuestionFocus(model, base.executionState);
      
      return {
        ...base,
        type: "brief",
        yesterdayPerformance,
        todayFocus,
        pendingCommitments,
        questionFocus,
      };
    }
    
    /**
     * Synthesize context for nudge generation.
     */
    async synthesizeForNudge(
      userId: string, 
      triggerType: string,
      triggerReason: string,
      severity: number = 3
    ): Promise<NudgeSynthesis> {
      const model = await deepUserModel.buildDeepUserModel(userId);
      const base = await this.buildBaseSynthesis(model);
      
      // Determine urgency
      let urgency: "low" | "medium" | "high" | "critical" = "medium";
      if (severity >= 5 || base.currentRisk.level === "critical") urgency = "critical";
      else if (severity >= 4 || base.currentRisk.level === "high") urgency = "high";
      else if (severity <= 2) urgency = "low";
      
      // Find what's at stake
      const atStake = this.findWhatIsAtStake(model, triggerType);
      
      // Find relevant pattern
      const relevantPattern = this.findRelevantPattern(model, triggerType);
      
      // Determine recommended action
      const recommendedAction = this.determineRecommendedAction(model, triggerType, urgency);
      
      return {
        ...base,
        type: "nudge",
        trigger: {
          type: triggerType,
          reason: triggerReason,
          severity,
          habitContext: atStake,
        },
        urgency,
        atStake,
        relevantPattern,
        recommendedAction,
      };
    }
    
    /**
     * Synthesize context for evening debrief generation.
     */
    async synthesizeForDebrief(userId: string): Promise<DebriefSynthesis> {
      const model = await deepUserModel.buildDeepUserModel(userId);
      const base = await this.buildBaseSynthesis(model);
      
      // Get today's actual performance
      const todayActual = await this.getTodayActual(userId, model);
      
      // Compare intention vs reality
      const intentionVsReality = this.compareIntentionVsReality(model, todayActual);
      
      // Analyze drift
      const driftAnalysis = await this.analyzeTodaysDrift(userId, model);
      
      // Setup for tomorrow
      const tomorrowSetup = this.setupForTomorrow(model);
      
      return {
        ...base,
        type: "debrief",
        todayActual,
        intentionVsReality,
        driftAnalysis,
        tomorrowSetup,
      };
    }
    
    /**
     * Synthesize context for chat response generation.
     */
    async synthesizeForChat(
      userId: string,
      conversationHistory: Array<{ role: string; content: string }>
    ): Promise<ChatSynthesis> {
      const model = await deepUserModel.buildDeepUserModel(userId);
      const base = await this.buildBaseSynthesis(model);
      
      // Analyze conversation context
      const conversationContext = this.analyzeConversation(conversationHistory);
      
      // Determine curiosities
      const curiosities = this.determineCuriosities(model, conversationContext);
      
      // Find patterns to potentially surface
      const patternsToSurface = this.findPatternsToSurface(model, conversationContext);
      
      // Get commitments to check on
      const commitmentsToCheck = model.learned?.commitments?.filter(
        c => c.status === "pending" && 
             new Date(c.madeAt).getTime() > Date.now() - 7 * 86400000
      ) || [];
      
      return {
        ...base,
        type: "chat",
        conversationContext,
        curiosities,
        patternsToSurface,
        commitmentsToCheck,
        fullPsychology: model.psychology,
      };
    }
    
    /**
     * Synthesize context for weekly letter generation.
     */
    async synthesizeForWeeklyLetter(userId: string): Promise<WeeklyLetterSynthesis> {
      const model = await deepUserModel.buildDeepUserModel(userId);
      const base = await this.buildBaseSynthesis(model);
      
      // Get week summary
      const weekSummary = await this.getWeekSummary(userId, model);
      
      // Get week over week comparison
      const weekOverWeek = await this.getWeekOverWeek(userId);
      
      // Get arc progress
      const arcProgress = this.getArcProgress(model);
      
      // Determine the one truth to deliver
      const truthToDeliver = this.determineTruthToDeliver(model, weekSummary);
      
      // Determine next week focus
      const nextWeekFocus = this.determineNextWeekFocus(model, weekSummary);
      
      return {
        ...base,
        type: "weekly_letter",
        weekSummary,
        weekOverWeek,
        arcProgress,
        truthToDeliver,
        nextWeekFocus,
      };
    }
    
    // ---------------------------------------------------------------------------
    // BASE SYNTHESIS BUILDER
    // ---------------------------------------------------------------------------
    
    private async buildBaseSynthesis(model: DeepUserModel): Promise<BaseMemorySynthesis> {
      // Determine execution state
      const { executionState, executionEvidence } = this.determineExecutionState(model);
      
      // Build voice calibration
      const voiceCalibration = this.buildVoiceCalibration(model, executionState);
      
      // Extract earned truths
      const earnedTruths = this.extractEarnedTruths(model);
      
      // Form hypotheses
      const hypotheses = this.formHypotheses(model);
      
      // Identify unknowns
      const unknowns = this.identifyUnknowns(model);
      
      // Get recent data snapshot
      const recentData = await this.getRecentDataSnapshot(model);
      
      // Get past reflections from Chroma for memory loop
      const { pastReflections, reflectionCount } = await this.getRelevantReflections(model.identity.userId);
      
      return {
        userId: model.identity.userId,
        userName: model.identity.name,
        executionState,
        executionEvidence,
        currentRisk: model.predictions.slipRisk,
        activeTriggerWarning: model.activeTriggerChainWarning,
        voiceCalibration,
        earnedTruths,
        hypotheses,
        unknowns,
        activeContradictions: model.contradictions.active,
        recentData,
        phase: model.arc.phase,
        daysInPhase: model.arc.daysInPhase,
        daysInSystem: model.identity.daysInSystem,
        purpose: model.identity.purpose,
        values: model.identity.values,
        shameSensitivity: model.psychology.shameSensitivity,
        recurringExcuses: model.psychology.recurringExcuses,
        timeWasters: model.psychology.timeWasters,
        modelConfidence: model.modelConfidence,
        pastReflections,
        reflectionCount,
      };
    }
    
    // ---------------------------------------------------------------------------
    // REFLECTION MEMORY LOOP (Chroma Integration)
    // ---------------------------------------------------------------------------
    
    /**
     * Query Chroma for relevant past reflections.
     * This is the memory loop that allows AI to say "You said last week..."
     */
    private async getRelevantReflections(userId: string): Promise<{
      pastReflections: Array<{ text: string; dayKey: string; source: string }>;
      reflectionCount: number;
    }> {
      try {
        // Get recent reflections from Chroma
        const recentMemories = await semanticMemory.getRecentMemories({
          userId,
          type: "reflection",
          limit: 10,
        });
        
        // Also count total reflections from Postgres for authority calculation
        const reflectionCount = await prisma.event.count({
          where: {
            userId,
            type: "reflection_answer",
          },
        });
        
        const pastReflections = recentMemories.map(m => ({
          text: m.text,
          dayKey: m.metadata?.dayKey || new Date(m.metadata?.timestamp || Date.now()).toISOString().split("T")[0],
          source: m.metadata?.source || "unknown",
        }));
        
        console.log(`📚 [MemorySynthesis] Loaded ${pastReflections.length} reflections for ${userId.substring(0, 8)}... (total: ${reflectionCount})`);
        
        return { pastReflections, reflectionCount };
      } catch (err) {
        console.warn(`⚠️ [MemorySynthesis] Failed to load reflections:`, err);
        return { pastReflections: [], reflectionCount: 0 };
      }
    }
    
    /**
     * Query Chroma for reflections relevant to a specific context.
     * Used when generating targeted messages that should reference past answers.
     */
    async getContextualReflections(userId: string, context: string): Promise<Array<{ text: string; dayKey: string; score: number }>> {
      try {
        const memories = await semanticMemory.queryMemories({
          userId,
          type: "reflection",
          query: context,
          limit: 5,
          minScore: 0.5,
        });
        
        return memories.map(m => ({
          text: m.text,
          dayKey: m.metadata?.dayKey || "recent",
          score: m.score,
        }));
      } catch (err) {
        console.warn(`⚠️ [MemorySynthesis] Failed to query contextual reflections:`, err);
        return [];
      }
    }
    
    // ---------------------------------------------------------------------------
    // STATE DETERMINATION
    // ---------------------------------------------------------------------------
    
    private determineExecutionState(model: DeepUserModel): {
      executionState: "ON_TRACK" | "MIDDLE" | "SLIP";
      executionEvidence: string[];
    } {
      const evidence: string[] = [];
      let score = 0; // -100 to +100
      
      // Factor 1: Recent completion rate
      const rate7d = model.behavior.last7DaysRate;
      if (rate7d >= 70) {
        score += 30;
        evidence.push(`Strong 7-day completion rate: ${rate7d}%`);
      } else if (rate7d >= 50) {
        score += 10;
        evidence.push(`Moderate 7-day completion rate: ${rate7d}%`);
      } else if (rate7d >= 30) {
        score -= 10;
        evidence.push(`Low 7-day completion rate: ${rate7d}%`);
      } else {
        score -= 30;
        evidence.push(`Very low 7-day completion rate: ${rate7d}%`);
      }
      
      // Factor 2: Days since last action
      const daysSince = model.behavior.daysSinceLastAction;
      if (daysSince === 0) {
        score += 20;
        evidence.push("Active today");
      } else if (daysSince === 1) {
        score += 10;
        evidence.push("Active yesterday");
      } else if (daysSince <= 3) {
        score -= 10;
        evidence.push(`${daysSince} days since last action`);
      } else {
        score -= 30;
        evidence.push(`${daysSince} days since last action (ghost territory)`);
      }
      
      // Factor 3: Active streaks
      const activeStreaks = model.behavior.habits.filter(h => h.streak >= 3).length;
      if (activeStreaks >= 3) {
        score += 20;
        evidence.push(`${activeStreaks} active streaks`);
      } else if (activeStreaks >= 1) {
        score += 10;
        evidence.push(`${activeStreaks} active streak(s)`);
      } else {
        score -= 10;
        evidence.push("No active streaks");
      }
      
      // Factor 4: Engagement pattern
      if (model.patterns.engagementPattern === "daily_engaged") {
        score += 20;
        evidence.push("Daily engaged pattern");
      } else if (model.patterns.engagementPattern === "ghost") {
        score -= 40;
        evidence.push("Ghost pattern detected");
      } else if (model.patterns.engagementPattern === "fading") {
        score -= 20;
        evidence.push("Fading engagement pattern");
      }
      
      // Factor 5: Slip risk
      if (model.predictions.slipRisk.level === "critical") {
        score -= 30;
        evidence.push("Critical slip risk");
      } else if (model.predictions.slipRisk.level === "high") {
        score -= 15;
        evidence.push("High slip risk");
      } else if (model.predictions.slipRisk.level === "low") {
        score += 15;
        evidence.push("Low slip risk");
      }
      
      // Determine state
      let executionState: "ON_TRACK" | "MIDDLE" | "SLIP";
      if (score >= 30) {
        executionState = "ON_TRACK";
      } else if (score >= -20) {
        executionState = "MIDDLE";
      } else {
        executionState = "SLIP";
      }
      
      return { executionState, executionEvidence: evidence };
    }
    
    // ---------------------------------------------------------------------------
    // VOICE CALIBRATION
    // ---------------------------------------------------------------------------
    
    private buildVoiceCalibration(
      model: DeepUserModel,
      executionState: "ON_TRACK" | "MIDDLE" | "SLIP"
    ): VoiceCalibration {
      // Data quality based on days in system
      let dataQuality: "sparse" | "developing" | "rich" | "comprehensive";
      if (model.identity.daysInSystem < 7) dataQuality = "sparse";
      else if (model.identity.daysInSystem < 30) dataQuality = "developing";
      else if (model.identity.daysInSystem < 90) dataQuality = "rich";
      else dataQuality = "comprehensive";
      
      // Authority based on data quality + days
      let authority: "humble" | "growing" | "earned" | "deep";
      if (model.identity.daysInSystem < 7) authority = "humble";
      else if (model.identity.daysInSystem < 30) authority = "growing";
      else if (model.identity.daysInSystem < 90) authority = "earned";
      else authority = "deep";
      
      // Max intensity from shame sensitivity
      const maxIntensity = model.psychology.shameSensitivity.maxMessageIntensity;
      
      // Current intensity based on state + risk
      let currentIntensity = 5; // Base
      if (executionState === "ON_TRACK") {
        currentIntensity = Math.min(6, maxIntensity);
      } else if (executionState === "SLIP") {
        // For slip, we might want to be softer or harder depending on shame sensitivity
        if (model.psychology.shameSensitivity.score > 0.6) {
          currentIntensity = Math.min(4, maxIntensity); // Softer for sensitive users
        } else {
          currentIntensity = Math.min(7, maxIntensity); // Can push harder
        }
      }
      
      // Approach style
      let approachStyle: "challenge" | "support" | "neutral" | "celebration";
      if (executionState === "ON_TRACK" && model.behavior.longestCurrentStreak >= 7) {
        approachStyle = "celebration";
      } else if (executionState === "SLIP") {
        approachStyle = model.psychology.shameSensitivity.score > 0.5 ? "support" : "challenge";
      } else if (executionState === "MIDDLE") {
        approachStyle = "neutral";
      } else {
        approachStyle = "challenge";
      }
      
      // Phase-specific tone
      let phaseTone: string;
      switch (model.arc.phase) {
        case "observer":
          phaseTone = "Curious and supportive. Ask questions to understand. Don't assume you know them yet.";
          break;
        case "architect":
          phaseTone = "Direct and structured. Reference specific patterns. Challenge inconsistencies.";
          break;
        case "oracle":
          phaseTone = "Calm and knowing. Use their own words. Ask questions that reveal destiny, not tactics.";
          break;
      }
      
      // Avoid/prefer phrases
      const avoidPhrases = model.psychology.shameSensitivity.score > 0.5
        ? ["you failed", "you didn't", "again", "disappointed", "why can't you"]
        : [];
      
      const preferPhrases = model.psychology.shameSensitivity.score > 0.5
        ? ["when you're ready", "no judgment", "let's", "we", "together"]
        : ["you know what to do", "prove it", "show up"];
      
      return {
        dataQuality,
        authority,
        maxIntensity,
        currentIntensity,
        approachStyle,
        requiresSoftLanding: model.psychology.shameSensitivity.requiresSoftLanding,
        phaseTone,
        avoidPhrases,
        preferPhrases,
      };
    }
    
    // ---------------------------------------------------------------------------
    // TRUTH EXTRACTION
    // ---------------------------------------------------------------------------
    
    private extractEarnedTruths(model: DeepUserModel): EarnedTruth[] {
      const truths: EarnedTruth[] = [];
      
      // Behavior truths (high confidence)
      if (model.behavior.last7DaysRate > 0) {
        truths.push({
          statement: `Your 7-day completion rate is ${model.behavior.last7DaysRate}%`,
          confidence: 1.0,
          evidence: "Direct calculation from completion data",
          category: "behavior",
        });
      }
      
      if (model.behavior.longestCurrentStreak > 0) {
        const habit = model.behavior.habits.find(h => h.streak === model.behavior.longestCurrentStreak);
        truths.push({
          statement: `Your longest current streak is ${model.behavior.longestCurrentStreak} days${habit ? ` (${habit.title})` : ""}`,
          confidence: 1.0,
          evidence: "Direct from habit data",
          category: "behavior",
        });
      }
      
      // Pattern truths (medium-high confidence)
      if (model.patterns.weakestDay) {
        truths.push({
          statement: `${model.patterns.weakestDay.dayName} is your weakest day (${model.patterns.weakestDay.completionRate}% completion)`,
          confidence: 0.8,
          evidence: `Based on ${model.identity.daysInSystem} days of data`,
          category: "pattern",
        });
      }
      
      if (model.patterns.driftWindows.length > 0) {
        const worst = model.patterns.driftWindows[0];
        truths.push({
          statement: `You tend to drift around ${worst.hourOfDay}:00 (${worst.completionRate}% completion)`,
          confidence: 0.7,
          evidence: `Observed ${worst.sampleSize} times`,
          category: "pattern",
        });
      }
      
      // Psychology truths (medium confidence)
      if (model.psychology.recurringExcuses.length > 0) {
        const topExcuse = model.psychology.recurringExcuses[0];
        if (topExcuse.frequency >= 3) {
          truths.push({
            statement: `"${topExcuse.phrase}" is a recurring excuse (used ${topExcuse.frequency} times)`,
            confidence: 0.7,
            evidence: "Detected in conversations",
            category: "psychology",
          });
        }
      }
      
      if (model.psychology.timeWasters.length > 0) {
        truths.push({
          statement: `Your main time wasters: ${model.psychology.timeWasters.slice(0, 3).join(", ")}`,
          confidence: 0.6,
          evidence: "Detected from patterns and conversations",
          category: "psychology",
        });
      }
      
      return truths;
    }
    
    private formHypotheses(model: DeepUserModel): Hypothesis[] {
      const hypotheses: Hypothesis[] = [];
      
      // Hypothesis from contradictions
      if (model.contradictions.primaryContradiction) {
        hypotheses.push({
          statement: model.contradictions.primaryContradiction.description,
          confidence: 0.5,
          basis: model.contradictions.primaryContradiction.evidence,
          shouldProbe: true,
        });
      }
      
      // Hypothesis from limiting narratives
      if (model.psychology.limitingNarratives.length > 0) {
        const narrative = model.psychology.limitingNarratives[0];
        hypotheses.push({
          statement: `You may believe "${narrative.narrative}" — which could be holding you back`,
          confidence: 0.4,
          basis: `Used ${narrative.frequency} times`,
          shouldProbe: !narrative.challenged,
        });
      }
      
      // Hypothesis from recovery style
      const fingerprint = model.learned?.fingerprint;
      if (fingerprint?.recoveryStyle.type === "sudden" && fingerprint.recoveryStyle.crashRiskAfterRestart > 0.5) {
        hypotheses.push({
          statement: "You tend to go all-in after breaks, then crash. Gradual restarts might work better.",
          confidence: 0.6, // Confidence based on pattern detection
          basis: fingerprint.recoveryStyle.evidence.join("; ") || "Observed pattern",
          shouldProbe: true,
        });
      }
      
      // Hypothesis from avoidance patterns
      if (model.patterns.avoidedHabits.length > 0) {
        hypotheses.push({
          statement: `You may be avoiding certain habits because they feel harder or more meaningful`,
          confidence: 0.5,
          basis: `${model.patterns.avoidedHabits.length} habits consistently missed`,
          shouldProbe: true,
        });
      }
      
      return hypotheses;
    }
    
    private identifyUnknowns(model: DeepUserModel): string[] {
      const unknowns: string[] = [];
      
      if (model.modelConfidence === "insufficient" || model.modelConfidence === "low") {
        unknowns.push("I don't have enough data to understand your patterns yet");
      }
      
      if (!model.identity.purpose) {
        unknowns.push("What is driving you to build these habits?");
      }
      
      if (model.psychology.motivationStyle === "unknown") {
        unknowns.push("What actually motivates you — progress, fear, identity, or something else?");
      }
      
      if (model.patterns.engagementPattern === "sporadic") {
        unknowns.push("What determines whether you show up on a given day?");
      }
      
      if (model.behavior.daysSinceLastAction > 2) {
        unknowns.push("What pulled you away?");
      }
      
      return unknowns;
    }
    
    // ---------------------------------------------------------------------------
    // RECENT DATA HELPERS
    // ---------------------------------------------------------------------------
    
    private async getRecentDataSnapshot(model: DeepUserModel): Promise<RecentDataSnapshot> {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      // Today's data from habits
      const todayHabits: TodayHabit[] = model.behavior.habits.map(h => ({
        title: h.title,
        completed: h.lastTick ? new Date(h.lastTick) >= today : false,
        streak: h.streak,
        scheduledTime: h.scheduledTime,
      }));
      
      const completedToday = todayHabits.filter(h => h.completed);
      const missedToday = todayHabits.filter(h => !h.completed && h.scheduledTime && this.isPastScheduledTime(h.scheduledTime));
      const pendingToday = todayHabits.filter(h => !h.completed && (!h.scheduledTime || !this.isPastScheduledTime(h.scheduledTime)));
      
      // Week data
      const weekRate = model.behavior.last7DaysRate;
      const prevWeekRate = model.behavior.last30DaysRate; // Approximate
      const weekTrend: "up" | "down" | "stable" = 
        weekRate > prevWeekRate + 10 ? "up" : 
        weekRate < prevWeekRate - 10 ? "down" : "stable";
      
      // Active streaks
      const activeStreaks = model.behavior.habits
        .filter(h => h.streak >= 3)
        .sort((a, b) => b.streak - a.streak)
        .slice(0, 5)
        .map(h => ({
          habitTitle: h.title,
          days: h.streak,
          atRisk: h.completionRate7d < 70,
        }));
      
      // Recent wins
      const recentWins = completedToday.slice(0, 3).map(h => h.title);
      
      // Last engagement
      const daysSince = model.behavior.daysSinceLastAction;
      let lastEngagement: string;
      if (daysSince === 0) lastEngagement = "today";
      else if (daysSince === 1) lastEngagement = "yesterday";
      else lastEngagement = `${daysSince} days ago`;
      
      return {
        today: {
          completions: todayHabits,
          completedCount: completedToday.length,
          missedCount: missedToday.length,
          pendingCount: pendingToday.length,
          completionRate: todayHabits.length > 0 
            ? Math.round((completedToday.length / todayHabits.length) * 100) 
            : 0,
        },
        week: {
          completed: Math.round(weekRate * model.behavior.totalHabits * 7 / 100),
          total: model.behavior.totalHabits * 7,
          rate: weekRate,
          trend: weekTrend,
        },
        activeStreaks,
        recentWins,
        lastEngagement,
        daysSinceLastAction: daysSince,
      };
    }
    
    private isPastScheduledTime(scheduledTime: string): boolean {
      const [hours, minutes] = scheduledTime.split(":").map(Number);
      const now = new Date();
      const scheduled = new Date();
      scheduled.setHours(hours, minutes, 0, 0);
      return now > scheduled;
    }
    
    // ---------------------------------------------------------------------------
    // BRIEF-SPECIFIC HELPERS
    // ---------------------------------------------------------------------------
    
    private async getYesterdayPerformance(userId: string, model: DeepUserModel): Promise<{
      completed: number;
      missed: number;
      rate: number;
      highlight: string | null;
    }> {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);
      
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const completions = await prisma.completion.findMany({
        where: {
          userId,
          date: {
            gte: yesterday,
            lt: today,
          },
        },
      });
      
      const completed = completions.filter(c => c.done).length;
      const missed = completions.filter(c => !c.done).length;
      const total = completed + missed;
      const rate = total > 0 ? Math.round((completed / total) * 100) : 0;
      
      // Find highlight
      let highlight: string | null = null;
      if (completed > 0) {
        const longestStreakHabit = model.behavior.habits
          .filter(h => h.lastTick && new Date(h.lastTick) >= yesterday)
          .sort((a, b) => b.streak - a.streak)[0];
        if (longestStreakHabit && longestStreakHabit.streak >= 3) {
          highlight = `${longestStreakHabit.title} streak now at ${longestStreakHabit.streak} days`;
        }
      }
      
      return { completed, missed, rate, highlight };
    }
    
    private determineTodayFocus(model: DeepUserModel): {
      priorityHabits: string[];
      driftWindowsToday: string[];
      streaksToProtect: string[];
    } {
      // Priority habits (high importance or at-risk streaks)
      const priorityHabits = model.behavior.habits
        .filter(h => h.importance >= 4 || (h.streak >= 7 && h.completionRate7d < 80))
        .slice(0, 3)
        .map(h => h.title);
      
      // Drift windows for today
      const today = new Date().getDay();
      const driftWindowsToday = model.patterns.driftWindows
        .filter(d => d.dayOfWeek === null || d.dayOfWeek === today)
        .map(d => `${d.hourOfDay}:00`);
      
      // Streaks to protect
      const streaksToProtect = model.behavior.habits
        .filter(h => h.streak >= 7)
        .slice(0, 3)
        .map(h => `${h.title} (${h.streak} days)`);
      
      return { priorityHabits, driftWindowsToday, streaksToProtect };
    }
    
    private determineQuestionFocus(
      model: DeepUserModel, 
      state: "ON_TRACK" | "MIDDLE" | "SLIP"
    ): "extract_fear" | "confront_pattern" | "clarify_intention" | "probe_excuse" | "celebrate_progress" {
      // If they're doing well, celebrate or push deeper
      if (state === "ON_TRACK") {
        if (model.behavior.longestCurrentStreak >= 14) {
          return "celebrate_progress";
        }
        return "clarify_intention";
      }
      
      // If they're slipping
      if (state === "SLIP") {
        // If we know their excuses, probe them
        if (model.psychology.recurringExcuses.length > 0) {
          return "probe_excuse";
        }
        // Otherwise try to extract fear
        return "extract_fear";
      }
      
      // Middle state - confront patterns
      if (model.contradictions.active.length > 0) {
        return "confront_pattern";
      }
      
      return "clarify_intention";
    }
    
    // ---------------------------------------------------------------------------
    // NUDGE-SPECIFIC HELPERS
    // ---------------------------------------------------------------------------
    
    private findWhatIsAtStake(model: DeepUserModel, triggerType: string): string | null {
      if (triggerType.includes("streak")) {
        const atRisk = model.behavior.habits
          .filter(h => h.streak >= 7)
          .sort((a, b) => b.streak - a.streak)[0];
        if (atRisk) {
          return `${atRisk.streak}-day ${atRisk.title} streak`;
        }
      }
      
      if (triggerType.includes("high_importance")) {
        const important = model.behavior.habits
          .filter(h => h.importance >= 4)
          .sort((a, b) => b.importance - a.importance)[0];
        if (important) {
          return important.title;
        }
      }
      
      return null;
    }
    
    private findRelevantPattern(model: DeepUserModel, triggerType: string): string | null {
      const now = new Date();
      const currentHour = now.getHours();
      
      // Check if we're in a known drift window
      const driftWindow = model.patterns.driftWindows.find(d => d.hourOfDay === currentHour);
      if (driftWindow) {
        return `This is your ${currentHour}:00 drift window — you complete only ${driftWindow.completionRate}% of habits at this time`;
      }
      
      // Check if it's their weak day
      const today = now.getDay();
      const dayPattern = model.patterns.dayOfWeekPatterns.find(d => d.day === today);
      if (dayPattern?.isWeakDay) {
        return `${dayPattern.dayName} is historically your weakest day (${dayPattern.completionRate}%)`;
      }
      
      // Check for recurring excuse pattern
      if (model.psychology.recurringExcuses.length > 0 && triggerType.includes("drift")) {
        return `Watch for the "${model.psychology.recurringExcuses[0].phrase}" excuse`;
      }
      
      return null;
    }
    
    private determineRecommendedAction(
      model: DeepUserModel, 
      triggerType: string,
      urgency: "low" | "medium" | "high" | "critical"
    ): string {
      if (urgency === "critical") {
        const topHabit = model.behavior.habits
          .filter(h => h.streak >= 7)
          .sort((a, b) => b.streak - a.streak)[0];
        if (topHabit) {
          return `Do ${topHabit.title} right now to protect your ${topHabit.streak}-day streak`;
        }
        return "Do one thing right now — anything — to break the freeze";
      }
      
      if (urgency === "high") {
        return "Pick the smallest habit and do it in the next 5 minutes";
      }
      
      if (triggerType.includes("momentum")) {
        return "What's the one thing you can knock out before noon?";
      }
      
      if (triggerType.includes("drift")) {
        return "Step away from the distraction and do one habit";
      }
      
      return "Check in with your intentions for today";
    }
    
    // ---------------------------------------------------------------------------
    // DEBRIEF-SPECIFIC HELPERS
    // ---------------------------------------------------------------------------
    
    private async getTodayActual(userId: string, model: DeepUserModel): Promise<{
      completed: TodayHabit[];
      missed: TodayHabit[];
      completionRate: number;
      bestMoment: string | null;
      hardestMoment: string | null;
    }> {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      // Query completions and habits separately (no relation defined in schema)
      const [completions, habits] = await Promise.all([
        prisma.completion.findMany({
          where: {
            userId,
            date: { gte: today },
          },
        }),
        prisma.habit.findMany({
          where: { userId },
          select: { id: true, title: true, streak: true, schedule: true },
        }),
      ]);
      
      // Build habit lookup map
      const habitMap = new Map(habits.map(h => [h.id, h]));
      
      const completed: TodayHabit[] = completions
        .filter(c => c.done)
        .map(c => {
          const habit = habitMap.get(c.habitId);
          return {
            title: habit?.title || "Unknown",
            completed: true,
            streak: habit?.streak || 0,
            scheduledTime: (habit?.schedule as any)?.time || null,
          };
        });
      
      const missed: TodayHabit[] = completions
        .filter(c => !c.done)
        .map(c => {
          const habit = habitMap.get(c.habitId);
          return {
            title: habit?.title || "Unknown",
            completed: false,
            streak: 0,
            scheduledTime: (habit?.schedule as any)?.time || null,
          };
        });
      
      const total = completed.length + missed.length;
      const rate = total > 0 ? Math.round((completed.length / total) * 100) : 0;
      
      // Best moment
      let bestMoment: string | null = null;
      const longestStreak = completed.sort((a, b) => b.streak - a.streak)[0];
      if (longestStreak && longestStreak.streak >= 3) {
        bestMoment = `Continuing your ${longestStreak.title} streak (${longestStreak.streak} days)`;
      } else if (completed.length > 0) {
        bestMoment = `Completing ${completed[0].title}`;
      }
      
      // Hardest moment
      let hardestMoment: string | null = null;
      if (missed.length > 0) {
        hardestMoment = `Missing ${missed[0].title}`;
      }
      
      return { completed, missed, completionRate: rate, bestMoment, hardestMoment };
    }
    
    private compareIntentionVsReality(
      model: DeepUserModel,
      todayActual: { completionRate: number }
    ): { aligned: boolean; gap: string | null } {
      // Compare to their typical performance
      const expected = model.behavior.last7DaysRate;
      const actual = todayActual.completionRate;
      
      if (Math.abs(actual - expected) <= 15) {
        return { aligned: true, gap: null };
      }
      
      if (actual < expected - 15) {
        return {
          aligned: false,
          gap: `Today was ${expected - actual}% below your recent average`,
        };
      }
      
      return {
        aligned: true,
        gap: `Today was ${actual - expected}% above your recent average`,
      };
    }
    
    private async analyzeTodaysDrift(userId: string, model: DeepUserModel): Promise<{
      driftedAt: string | null;
      driftCause: string | null;
      recoveredAt: string | null;
    }> {
      // Get today's events
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const events = await prisma.event.findMany({
        where: {
          userId,
          ts: { gte: today },
        },
        orderBy: { ts: "asc" },
      });
      
      // Look for gaps in activity
      let driftedAt: string | null = null;
      let recoveredAt: string | null = null;
      
      for (let i = 1; i < events.length; i++) {
        const prev = new Date(events[i - 1].ts);
        const curr = new Date(events[i].ts);
        const gapHours = (curr.getTime() - prev.getTime()) / 3600000;
        
        if (gapHours > 4 && !driftedAt) {
          driftedAt = `${prev.getHours()}:00`;
          recoveredAt = `${curr.getHours()}:00`;
          break;
        }
      }
      
      // Drift cause (if we have time wasters)
      const driftCause = model.psychology.timeWasters.length > 0
        ? `Possibly: ${model.psychology.timeWasters[0]}`
        : null;
      
      return { driftedAt, driftCause, recoveredAt };
    }
    
    private setupForTomorrow(model: DeepUserModel): {
      priorityHabit: string | null;
      riskWindow: string | null;
      commitmentToProbe: string | null;
    } {
      // Tomorrow's priority
      const priorityHabit = model.behavior.habits
        .filter(h => h.importance >= 4 || h.streak >= 7)
        .sort((a, b) => b.importance - a.importance)[0]?.title || null;
      
      // Tomorrow's risk window
      const tomorrow = (new Date().getDay() + 1) % 7;
      const tomorrowDrift = model.patterns.driftWindows.find(
        d => d.dayOfWeek === null || d.dayOfWeek === tomorrow
      );
      const riskWindow = tomorrowDrift ? `${tomorrowDrift.hourOfDay}:00` : null;
      
      // Commitment to probe
      const pendingCommitment = model.learned?.commitments?.find(c => c.status === "pending");
      const commitmentToProbe = pendingCommitment?.text || null;
      
      return { priorityHabit, riskWindow, commitmentToProbe };
    }
    
    // ---------------------------------------------------------------------------
    // CHAT-SPECIFIC HELPERS
    // ---------------------------------------------------------------------------
    
    private analyzeConversation(history: Array<{ role: string; content: string }>): {
      recentMessages: Array<{ role: string; content: string }>;
      emotionalTone: string;
      topicThread: string | null;
    } {
      const recentMessages = history.slice(-10);
      
      // Simple emotional tone detection
      const lastUserMessage = recentMessages.filter(m => m.role === "user").pop();
      let emotionalTone = "neutral";
      if (lastUserMessage) {
        const text = lastUserMessage.content.toLowerCase();
        if (text.includes("frustrated") || text.includes("angry") || text.includes("annoyed")) {
          emotionalTone = "frustrated";
        } else if (text.includes("happy") || text.includes("great") || text.includes("excited")) {
          emotionalTone = "energized";
        } else if (text.includes("tired") || text.includes("exhausted") || text.includes("burnt")) {
          emotionalTone = "depleted";
        } else if (text.includes("confused") || text.includes("lost") || text.includes("don't know")) {
          emotionalTone = "confused";
        }
      }
      
      // Topic thread (simple keyword detection)
      let topicThread: string | null = null;
      const allText = recentMessages.map(m => m.content).join(" ").toLowerCase();
      if (allText.includes("streak") || allText.includes("habit")) {
        topicThread = "habits";
      } else if (allText.includes("goal") || allText.includes("purpose") || allText.includes("why")) {
        topicThread = "purpose";
      } else if (allText.includes("slip") || allText.includes("fail") || allText.includes("miss")) {
        topicThread = "recovery";
      }
      
      return { recentMessages, emotionalTone, topicThread };
    }
    
    private determineCuriosities(
      model: DeepUserModel,
      context: { topicThread: string | null }
    ): string[] {
      const curiosities: string[] = [];
      
      if (model.psychology.recurringExcuses.length > 0) {
        curiosities.push(`What's really behind "${model.psychology.recurringExcuses[0].phrase}"?`);
      }
      
      if (model.contradictions.primaryContradiction) {
        curiosities.push(`How do they explain the gap: ${model.contradictions.primaryContradiction.description}`);
      }
      
      if (model.patterns.avoidedHabits.length > 0) {
        curiosities.push("Why do they avoid certain habits consistently?");
      }
      
      if (context.topicThread === "recovery" && model.behavior.daysSinceLastAction > 2) {
        curiosities.push("What specifically pulled them away?");
      }
      
      return curiosities;
    }
    
    private findPatternsToSurface(
      model: DeepUserModel,
      context: { topicThread: string | null }
    ): string[] {
      const patterns: string[] = [];
      
      // Only surface patterns if we have earned authority
      if (model.identity.daysInSystem < 14) {
        return patterns;
      }
      
      if (model.patterns.weakestDay) {
        patterns.push(`${model.patterns.weakestDay.dayName} is consistently their weak day`);
      }
      
      if (model.patterns.driftWindows.length > 0) {
        const drift = model.patterns.driftWindows[0];
        patterns.push(`They drift around ${drift.hourOfDay}:00 (${drift.completionRate}% completion)`);
      }
      
      if (model.learned?.fingerprint?.celebrationTrap.type === "coast") {
        patterns.push("They tend to coast after hitting milestones");
      }
      
      return patterns;
    }
    
    // ---------------------------------------------------------------------------
    // WEEKLY LETTER-SPECIFIC HELPERS
    // ---------------------------------------------------------------------------
    
    private async getWeekSummary(userId: string, model: DeepUserModel): Promise<{
      totalCompleted: number;
      totalMissed: number;
      overallRate: number;
      bestDay: string;
      worstDay: string;
      trend: "improving" | "declining" | "stable";
    }> {
      const weekAgo = new Date(Date.now() - 7 * 86400000);
      
      const completions = await prisma.completion.findMany({
        where: { userId, date: { gte: weekAgo } },
      });
      
      const completed = completions.filter(c => c.done).length;
      const missed = completions.filter(c => !c.done).length;
      const total = completed + missed;
      const rate = total > 0 ? Math.round((completed / total) * 100) : 0;
      
      // Best/worst day
      const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      const bestDayPattern = model.patterns.strongestDay;
      const worstDayPattern = model.patterns.weakestDay;
      
      // Trend
      const trend: "improving" | "declining" | "stable" = 
        model.behavior.last7DaysRate > model.behavior.last30DaysRate + 10 ? "improving" :
        model.behavior.last7DaysRate < model.behavior.last30DaysRate - 10 ? "declining" : "stable";
      
      return {
        totalCompleted: completed,
        totalMissed: missed,
        overallRate: rate,
        bestDay: bestDayPattern?.dayName || "Unknown",
        worstDay: worstDayPattern?.dayName || "Unknown",
        trend,
      };
    }
    
    private async getWeekOverWeek(userId: string): Promise<{
      thisWeek: number;
      lastWeek: number;
      change: number;
      changeDescription: string;
    }> {
      const now = Date.now();
      const weekAgo = new Date(now - 7 * 86400000);
      const twoWeeksAgo = new Date(now - 14 * 86400000);
      
      const [thisWeekCompletions, lastWeekCompletions] = await Promise.all([
        prisma.completion.findMany({
          where: { userId, date: { gte: weekAgo } },
        }),
        prisma.completion.findMany({
          where: { userId, date: { gte: twoWeeksAgo, lt: weekAgo } },
        }),
      ]);
      
      const thisWeekRate = thisWeekCompletions.length > 0
        ? Math.round((thisWeekCompletions.filter(c => c.done).length / thisWeekCompletions.length) * 100)
        : 0;
      
      const lastWeekRate = lastWeekCompletions.length > 0
        ? Math.round((lastWeekCompletions.filter(c => c.done).length / lastWeekCompletions.length) * 100)
        : 0;
      
      const change = thisWeekRate - lastWeekRate;
      
      let changeDescription: string;
      if (change > 15) changeDescription = "Significant improvement";
      else if (change > 5) changeDescription = "Slight improvement";
      else if (change < -15) changeDescription = "Significant decline";
      else if (change < -5) changeDescription = "Slight decline";
      else changeDescription = "Holding steady";
      
      return {
        thisWeek: thisWeekRate,
        lastWeek: lastWeekRate,
        change,
        changeDescription,
      };
    }
    
    private getArcProgress(model: DeepUserModel): {
      milestonesThisWeek: string[];
      nextMilestone: string | null;
      narrativeShift: string | null;
    } {
      const weekAgo = new Date(Date.now() - 7 * 86400000);
      
      const milestonesThisWeek = model.arc.milestones
        .filter(m => new Date(m.achievedAt) >= weekAgo)
        .map(m => m.description);
      
      return {
        milestonesThisWeek,
        nextMilestone: model.arc.nextMilestone,
        narrativeShift: null, // Would need historical comparison
      };
    }
    
    private determineTruthToDeliver(
      model: DeepUserModel,
      weekSummary: { overallRate: number; trend: "improving" | "declining" | "stable" }
    ): string | null {
      // If declining and they have a contradiction
      if (weekSummary.trend === "declining" && model.contradictions.primaryContradiction) {
        return model.contradictions.primaryContradiction.description;
      }
      
      // If they have a limiting narrative that's been unchallenged
      const unchallenged = model.psychology.limitingNarratives.find(n => !n.challenged);
      if (unchallenged) {
        return `You keep saying "${unchallenged.narrative}" — but is it true, or is it a story you're telling yourself?`;
      }
      
      // If they're coasting
      if (model.learned?.fingerprint?.celebrationTrap.type === "coast" && weekSummary.trend === "declining") {
        return "You tend to ease up after progress. This week might be that pattern repeating.";
      }
      
      // If improving
      if (weekSummary.trend === "improving" && weekSummary.overallRate >= 70) {
        return "Your consistency is becoming who you are, not just what you do.";
      }
      
      return null;
    }
    
    private determineNextWeekFocus(
      model: DeepUserModel,
      weekSummary: { worstDay: string; trend: "improving" | "declining" | "stable" }
    ): string | null {
      if (weekSummary.trend === "declining") {
        return "Rebuild momentum with small wins — don't try to fix everything at once";
      }
      
      if (model.patterns.weakestDay) {
        return `Own ${model.patterns.weakestDay.dayName} — it's been your leak`;
      }
      
      if (model.patterns.avoidedHabits.length > 0) {
        return "Face the habit you've been avoiding";
      }
      
      if (weekSummary.trend === "improving") {
        return "Maintain momentum — don't let success become complacency";
      }
      
      return null;
    }
  }
  
  // =============================================================================
  // EXPORT SINGLETON
  // =============================================================================
  
  export const memorySynthesis = new MemorySynthesisService();
  