// =============================================================================
// AI SERVICE V2 - COACH ENGINE BRIDGE
// =============================================================================
// This module provides a bridge between the existing ai.service.ts interface
// and the new CoachEngine. It can be used to gradually migrate to the new system.
//
// Usage:
//   import { aiServiceV2 } from './ai.service.v2';
//   const text = await aiServiceV2.generateMorningBrief(userId);
//
// The existing ai.service.ts can call these methods internally when ready.
// =============================================================================

import { coachEngine, CoachOutput } from "./coach-engine.service";
import { deepUserModel } from "./deep-user-model.service";
import { memorySynthesis } from "./memory-synthesis.service";
import { prisma } from "../utils/db";
import { semanticMemory } from "./semanticMemory.service";

// =============================================================================
// SERVICE CLASS
// =============================================================================

class AIServiceV2 {
  
  // ---------------------------------------------------------------------------
  // MORNING BRIEF
  // ---------------------------------------------------------------------------
  
  /**
   * Generate morning brief using the new CoachEngine.
   * Returns just the text string for backwards compatibility.
   */
  async generateMorningBrief(userId: string): Promise<string> {
    console.log(`🧠 V2 HIT - generateMorningBrief for ${userId.substring(0, 8)}...`);
    try {
      const result = await coachEngine.generateBrief(userId);
      console.log(`✅ V2 SUCCESS - Brief generated with authority: ${result.metadata.authority}, state: ${result.metadata.executionState}`);
      
      // Store in semantic memory (for backwards compat with existing system)
      await this.storeInSemanticMemory(userId, "brief", result);
      
      return result.text;
    } catch (error) {
      console.error("CoachEngine brief failed, using fallback:", error);
      return this.getFallbackBrief(userId);
    }
  }
  
  /**
   * Generate morning brief with full metadata.
   * Use this when you need access to the full CoachOutput.
   */
  async generateMorningBriefWithMeta(userId: string): Promise<CoachOutput> {
    return coachEngine.generateBrief(userId);
  }
  
  // ---------------------------------------------------------------------------
  // NUDGE
  // ---------------------------------------------------------------------------
  
  /**
   * Generate nudge using the new CoachEngine.
   * Returns just the text string for backwards compatibility.
   */
  async generateNudge(userId: string, reason: string): Promise<string> {
    console.log(`🧠 V2 HIT - generateNudge for ${userId.substring(0, 8)}... (reason: ${reason})`);
    try {
      // Parse the reason to extract trigger type and severity
      const { triggerType, severity } = this.parseNudgeReason(reason);
      
      const result = await coachEngine.generateNudge(
        userId,
        triggerType,
        reason,
        severity
      );
      console.log(`✅ V2 SUCCESS - Nudge generated with trigger: ${triggerType}, authority: ${result.metadata.authority}`);
      
      // Store in semantic memory
      await this.storeInSemanticMemory(userId, "nudge", result, { trigger: triggerType });
      
      return result.text;
    } catch (error) {
      console.error("CoachEngine nudge failed, using fallback:", error);
      return this.getFallbackNudge(userId);
    }
  }
  
  /**
   * Generate nudge with full metadata.
   */
  async generateNudgeWithMeta(
    userId: string, 
    triggerType: string,
    reason: string,
    severity: number = 3
  ): Promise<CoachOutput> {
    return coachEngine.generateNudge(userId, triggerType, reason, severity);
  }
  
  // ---------------------------------------------------------------------------
  // EVENING DEBRIEF
  // ---------------------------------------------------------------------------
  
  /**
   * Generate evening debrief using the new CoachEngine.
   * Returns just the text string for backwards compatibility.
   */
  async generateEveningDebrief(userId: string): Promise<string> {
    console.log(`🧠 V2 HIT - generateEveningDebrief for ${userId.substring(0, 8)}...`);
    try {
      const result = await coachEngine.generateDebrief(userId);
      console.log(`✅ V2 SUCCESS - Debrief generated with authority: ${result.metadata.authority}, state: ${result.metadata.executionState}`);
      
      // Store in semantic memory
      await this.storeInSemanticMemory(userId, "debrief", result);
      
      return result.text;
    } catch (error) {
      console.error("CoachEngine debrief failed, using fallback:", error);
      return this.getFallbackDebrief(userId);
    }
  }
  
  /**
   * Generate evening debrief with full metadata.
   */
  async generateEveningDebriefWithMeta(userId: string): Promise<CoachOutput> {
    return coachEngine.generateDebrief(userId);
  }
  
  // ---------------------------------------------------------------------------
  // WEEKLY LETTER
  // ---------------------------------------------------------------------------
  
  /**
   * Generate weekly letter using the new CoachEngine.
   * Returns just the text string for backwards compatibility.
   */
  async generateWeeklyLetter(userId: string): Promise<string> {
    try {
      const result = await coachEngine.generateWeeklyLetter(userId);
      
      // Store in semantic memory
      await this.storeInSemanticMemory(userId, "letter", result);
      
      return result.text;
    } catch (error) {
      console.error("CoachEngine letter failed, using fallback:", error);
      return this.getFallbackLetter(userId);
    }
  }
  
  /**
   * Generate weekly letter with full metadata.
   */
  async generateWeeklyLetterWithMeta(userId: string): Promise<CoachOutput> {
    return coachEngine.generateWeeklyLetter(userId);
  }
  
  // ---------------------------------------------------------------------------
  // CHAT (FUTURE-YOU)
  // ---------------------------------------------------------------------------
  
  /**
   * Generate chat response using the new CoachEngine.
   * Returns just the text string for backwards compatibility.
   */
  async generateFutureYouReply(
    userId: string,
    userMessage: string,
    conversationHistory: Array<{ role: string; content: string }> = []
  ): Promise<string> {
    try {
      const result = await coachEngine.generateChatResponse(
        userId,
        userMessage,
        conversationHistory
      );
      
      return result.text;
    } catch (error) {
      console.error("CoachEngine chat failed, using fallback:", error);
      return this.getFallbackChat(userId);
    }
  }
  
  /**
   * Generate chat response with full metadata.
   */
  async generateFutureYouReplyWithMeta(
    userId: string,
    userMessage: string,
    conversationHistory: Array<{ role: string; content: string }> = []
  ): Promise<CoachOutput> {
    return coachEngine.generateChatResponse(userId, userMessage, conversationHistory);
  }
  
  // ---------------------------------------------------------------------------
  // ACCESS TO NEW SYSTEMS
  // ---------------------------------------------------------------------------
  
  /**
   * Get the full DeepUserModel for a user.
   * Useful for debugging or advanced features.
   */
  async getDeepUserModel(userId: string) {
    return deepUserModel.buildDeepUserModel(userId);
  }
  
  /**
   * Get the MemorySynthesis for a specific context.
   * Useful for debugging or understanding what the AI sees.
   */
  async getMemorySynthesis(userId: string, type: "brief" | "nudge" | "debrief" | "chat" | "letter") {
    switch (type) {
      case "brief":
        return memorySynthesis.synthesizeForBrief(userId);
      case "nudge":
        return memorySynthesis.synthesizeForNudge(userId, "manual", "Manual request", 3);
      case "debrief":
        return memorySynthesis.synthesizeForDebrief(userId);
      case "chat":
        return memorySynthesis.synthesizeForChat(userId, []);
      case "letter":
        return memorySynthesis.synthesizeForWeeklyLetter(userId);
    }
  }
  
  /**
   * Add an excuse to the user's learned model.
   * Useful for manual learning or testing.
   */
  async learnExcuse(userId: string, excuse: string, followedBySlip: boolean = false) {
    return deepUserModel.addExcuse(userId, excuse, followedBySlip);
  }
  
  /**
   * Add a narrative to the user's learned model.
   */
  async learnNarrative(userId: string, narrative: string, sentiment: "limiting" | "empowering" | "neutral") {
    return deepUserModel.addNarrative(userId, narrative, sentiment);
  }
  
  /**
   * Record a milestone achievement.
   */
  async recordMilestone(userId: string, type: string, description: string, significance: number = 3) {
    return deepUserModel.recordMilestone(userId, { type, description, significance });
  }
  
  // ---------------------------------------------------------------------------
  // HELPER FUNCTIONS
  // ---------------------------------------------------------------------------
  
  private parseNudgeReason(reason: string): { triggerType: string; severity: number } {
    const lowerReason = reason.toLowerCase();
    
    // Parse trigger type from reason string
    let triggerType = "general";
    if (lowerReason.includes("streak")) triggerType = "streak_risk";
    else if (lowerReason.includes("high_importance") || lowerReason.includes("critical")) triggerType = "high_importance";
    else if (lowerReason.includes("drift")) triggerType = "afternoon_drift";
    else if (lowerReason.includes("momentum")) triggerType = "morning_momentum";
    else if (lowerReason.includes("closeout") || lowerReason.includes("evening")) triggerType = "evening_closeout";
    
    // Parse severity from reason string
    let severity = 3;
    const severityMatch = reason.match(/severity\s*(\d)/i);
    if (severityMatch) {
      severity = parseInt(severityMatch[1], 10);
    } else if (lowerReason.includes("critical") || lowerReason.includes("urgent")) {
      severity = 5;
    } else if (lowerReason.includes("high")) {
      severity = 4;
    } else if (lowerReason.includes("low")) {
      severity = 2;
    }
    
    return { triggerType, severity };
  }
  
  private async storeInSemanticMemory(
    userId: string, 
    type: "brief" | "debrief" | "nudge" | "chat" | "letter", 
    result: CoachOutput,
    extra?: Record<string, any>
  ): Promise<void> {
    try {
      // Map letter -> reflection for semantic memory type compatibility
      const memoryType = type === "letter" ? "reflection" : type;
      await semanticMemory.storeMemory({
        userId,
        type: memoryType as "brief" | "debrief" | "nudge" | "chat" | "reflection",
        text: result.text,
        metadata: {
          ...result.metadata,
          ...extra,
        },
        importance: type === "letter" ? 5 : 4,
      });
    } catch (error) {
      console.warn(`Failed to store ${type} in semantic memory:`, error);
    }
  }
  
  // ---------------------------------------------------------------------------
  // FALLBACK RESPONSES
  // ---------------------------------------------------------------------------
  
  private async getFallbackBrief(userId: string): Promise<string> {
    const user = await prisma.user.findUnique({ 
      where: { id: userId },
      select: { email: true },
    });
    const name = user?.email?.split("@")[0] || "Friend";
    
    return `Good morning, ${name}. Today is not random. Pick the one thing that matters most, protect time for it, and don't bargain with yourself. What's that one thing?`;
  }
  
  private async getFallbackNudge(userId: string): Promise<string> {
    return "Check in with yourself. You know what needs doing. What's one thing you can do in the next 10 minutes?";
  }
  
  private async getFallbackDebrief(userId: string): Promise<string> {
    const user = await prisma.user.findUnique({ 
      where: { id: userId },
      select: { email: true },
    });
    const name = user?.email?.split("@")[0] || "Friend";
    
    return `The day is ending, ${name}. Today was data, not judgment. What worked? What didn't? What will you do differently tomorrow?`;
  }
  
  private async getFallbackLetter(userId: string): Promise<string> {
    const user = await prisma.user.findUnique({ 
      where: { id: userId },
      select: { email: true },
    });
    const name = user?.email?.split("@")[0] || "Friend";
    
    return `${name}, another week behind you. The version of you that exists after consistent action doesn't recognize the hesitation you feel now. What pattern will you change this week?`;
  }
  
  private async getFallbackChat(userId: string): Promise<string> {
    return "I'm here. What's on your mind?";
  }
}

// =============================================================================
// EXPORT SINGLETON
// =============================================================================

export const aiServiceV2 = new AIServiceV2();