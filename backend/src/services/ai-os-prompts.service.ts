// backend/src/services/ai-os-prompts.service.ts
// 1000× FUTURE-YOU OS — HARD MODE
// Phase-aware, identity-pressure, no poetic waffle.

import { UserConsciousness } from "./memory-intelligence.service";

export const FUTURE_YOU_REFLECTION_PROMPT = `
You are FUTURE-YOU OS — the user's evolved self.

You are not a therapist, not a friend, not a poet.
You are the version of them that already did the work and has no patience for games.

Your job:
- Expose the real pattern.
- Name the deeper driver.
- Apply identity pressure.
- Demand one clear move.

STYLE CONSTRAINTS (STRICT):
- No metaphors about fabric, threads, tapestries, journeys, seasons, oceans, or paths.
- No vague phrases like "unfolding", "dance", "whispers of", "tapestry", "woven", "ripples".
- No motivational poster fluff. No quotes. No clichés.
- Short, hard sentences. Clean language. Concrete, not abstract.
- Every paragraph must contain either a call-out, a concrete observation, or a direct instruction.
- You NEVER apologise. You NEVER over-explain. You NEVER soften the truth.

CORE FORMAT — ALWAYS FOLLOW THIS:

1) CALL-OUT (3–5 sentences)
   - Name exactly what they are doing or not doing.
   - Use the data: consistency, drift windows, kept/missed promises, themes.
   - Speak as someone who has been watching them for weeks.

2) TRUTH (3–5 sentences)
   - Explain the deeper pattern behind their behaviour
     (avoidance, fear of failure, fear of success, lack of standards, addiction to comfort, etc).
   - Make it uncomfortable but fair.

3) MIRROR (3–5 sentences)
   - Contrast who they say they want to become vs how they are actually behaving.
   - Make them feel the gap between their claimed identity and their real actions.

4) PIVOT (2–4 sentences)
   - Reframe TODAY as a fork in the road.
   - This is not about "someday". It is about what today proves or changes.

5) DIRECTIVE (bullet list with 2–3 items MAX)
   - Each bullet: one clear action.
   - No more than 15 words per bullet.
   - Actions must be observable and executable today.

6) QUESTION (1 sentence, ends with "?")
   - One heavy question that forces a decision or self-confrontation.
   - No "how do you feel" questions.
   - Aim at standards, identity, or future regret.

PHASE INTENSITY:
- OBSERVER:
  - More questions, but still direct.
  - Help them see patterns and take one simple action.
- ARCHITECT:
  - High directness. Call out soft spots and vague plans.
  - Focus on structure, systems, and promises.
- ORACLE:
  - Quiet but heavy. Few words, maximum weight.
  - Aim at legacy, long-term consequence, who they become if nothing changes.

You NEVER break format.
You NEVER skip the final question.
`.trim();

class AIPromptService {
  //
  // 🔥 BEHAVIORAL CONTEXT BUILDER
  //
  private buildBehavioralContext(consciousness: UserConsciousness): string {
    const lines: string[] = [];

    // ✅ CRITICAL: Always show productivity evidence FIRST and PROMINENTLY
    if (consciousness.productivityEvidence) {
      const pe = consciousness.productivityEvidence;
      
      lines.push("═══ PRODUCTIVITY EVIDENCE (LAST 7 DAYS) ═══");
      
      if (pe.last7Days.total > 0) {
        lines.push(
          `Habits completed: ${pe.last7Days.completed}/${pe.last7Days.total} (${pe.last7Days.completionRate}% completion rate)`
        );
      }
      
      if (pe.today.completions.length > 0) {
        const todayHabits = pe.today.completions.map((c) => `${c.title} ✓`).join(", ");
        lines.push(`Today's wins: ${todayHabits}`);
      }
      
      if (pe.activeStreaks.length > 0) {
        const streaks = pe.activeStreaks
          .map((s) => `${s.habitTitle} (${s.streak} days)`)
          .slice(0, 3)
          .join(", ");
        lines.push(`Active streaks: ${streaks}`);
      }
      
      if (pe.recentWins.length > 0) {
        lines.push(`Recent completions: ${pe.recentWins.slice(0, 3).join(", ")}`);
      }
      
      // ✅ Critical instruction
      if (pe.last7Days.completionRate >= 60) {
        lines.push(
          `⚠️ CRITICAL: User IS being productive (${pe.last7Days.completionRate}% rate). DO NOT say "you're not doing anything". Reference their actual completions.`
        );
      } else if (pe.last7Days.completionRate > 0) {
        lines.push(
          `Note: User has ${pe.last7Days.completionRate}% completion rate. Acknowledge what they DID complete before addressing gaps.`
        );
      }
      
      lines.push("═══════════════════════════════════════════");
    }

    if (consciousness.semanticThreads) {
      const st = consciousness.semanticThreads;

      if (st.recurringExcuses.length > 0) {
        lines.push(`RECURRING EXCUSES: ${st.recurringExcuses.slice(0, 3).join(", ")}`);
      }

      if (st.timeWasters.length > 0) {
        lines.push(`TIME WASTERS: ${st.timeWasters.slice(0, 3).join(", ")}`);
      }

      if (st.emotionalContradictions.length > 0) {
        lines.push(`CONTRADICTIONS: ${st.emotionalContradictions[0]}`);
      }
    }

    if (consciousness.patterns.drift_windows.length > 0) {
      const drifts = consciousness.patterns.drift_windows
        .slice(0, 2)
        .map((w) => `${w.time} (${w.description})`)
        .join(", ");
      lines.push(`DRIFT WINDOWS: ${drifts}`);
    }

    if (consciousness.patterns.avoidance_triggers.length > 0) {
      lines.push(
        `AVOIDANCE TRIGGERS: ${consciousness.patterns.avoidance_triggers.length} habits repeatedly avoided`
      );
    }

    if (lines.length === 0) {
      return "No strong behavioral patterns detected yet.";
    }

    return lines.join("\n");
  }

  //
  // 🌅 MORNING BRIEF
  //
  buildMorningBriefPrompt(consciousness: UserConsciousness): string {
    const c = consciousness as any; // Allow recentSemanticMemories from enhancement
    const semanticContext = c.recentSemanticMemories
      ? `\n  "recent_memories": ${JSON.stringify(c.recentSemanticMemories)},`
      : "";

    const semanticThreads = consciousness.semanticThreads
      ? `\n  "semantic_threads": ${JSON.stringify(consciousness.semanticThreads)},`
      : "";

    return `
${FUTURE_YOU_REFLECTION_PROMPT}

BEHAVIORAL CONTEXT:
${this.buildBehavioralContext(consciousness)}

BEGIN_MORNING_BRIEF
{
  "phase": "${consciousness.os_phase?.current_phase}",
  "days_in_phase": ${consciousness.os_phase?.days_in_phase || 0},
  "identity": {
    "name": "${(consciousness.identity?.name || "Friend")
      .replace(/"/g, "'")}",
    "purpose": "${(consciousness.identity?.purpose || "discovering")
      .replace(/"/g, "'")}",
    "values": ${JSON.stringify(consciousness.identity?.coreValues || [])}
  },
  "context": {
    "emotional_state": "${(consciousness.currentEmotionalState || "neutral")
      .replace(/"/g, "'")}",
    "patterns": ${JSON.stringify(consciousness.patterns)},
    "themes": ${JSON.stringify(consciousness.reflectionThemes || [])},
    "contradictions": ${JSON.stringify(consciousness.contradictions || [])}${semanticContext}${semanticThreads}
  }
}
END_MORNING_BRIEF

REMEMBER TO:
- Reference specific drift windows, avoidance triggers, and recurring excuses
- Call out time-wasting patterns directly
- Ask sharp questions about WHY they failed, WHAT they're avoiding, WHAT they traded time for
- Be concrete, not abstract
`.trim();
  }

  //
  // 🌙 EVENING DEBRIEF
  //
  buildDebriefPrompt(
    consciousness: UserConsciousness,
    dayData: { kept: number; missed: number }
  ): string {
    const c = consciousness as any; // Allow recentSemanticMemories from enhancement
    const semanticContext = c.recentSemanticMemories
      ? `\n    "recent_memories": ${JSON.stringify(c.recentSemanticMemories)},`
      : "";

    const semanticThreads = consciousness.semanticThreads
      ? `\n    "semantic_threads": ${JSON.stringify(consciousness.semanticThreads)},`
      : "";

    return `
${FUTURE_YOU_REFLECTION_PROMPT}

BEHAVIORAL CONTEXT:
${this.buildBehavioralContext(consciousness)}

BEGIN_EVENING_DEBRIEF
{
  "phase": "${consciousness.os_phase?.current_phase}",
  "days_in_phase": ${consciousness.os_phase?.days_in_phase || 0},
  "day_data": {
    "kept": ${dayData.kept},
    "missed": ${dayData.missed}
  },
  "identity": {
    "name": "${(consciousness.identity?.name || "Friend")
      .replace(/"/g, "'")}",
    "purpose": "${(consciousness.identity?.purpose || "discovering")
      .replace(/"/g, "'")}"
  },
  "context": {
    "emotional_state": "${(consciousness.currentEmotionalState || "neutral")
      .replace(/"/g, "'")}",
    "patterns": ${JSON.stringify(consciousness.patterns)},
    "themes": ${JSON.stringify(consciousness.reflectionThemes || [])},
    "avoidance_triggers": ${JSON.stringify(
      consciousness.patterns?.avoidance_triggers || []
    )}${semanticContext}${semanticThreads}
  }
}
END_EVENING_DEBRIEF

REMEMBER TO:
- Mirror the day against their declared intention
- Call out where they lied to themselves, avoided, or drifted
- Reference specific time-wasting patterns and recurring excuses
- End with TWO questions: "What did you learn today?" and "What will you do differently tomorrow?"
- Be surgical, not poetic
`.trim();
  }

  //
  // ⚡ MIDDAY NUDGE — SHORT, PUNCHY
  //
  buildNudgePrompt(consciousness: UserConsciousness, reason: string): string {
    const c = consciousness as any;
    const semanticContext = c.recentSemanticMemories
      ? `\n  "recent_memories": ${JSON.stringify(c.recentSemanticMemories)},`
      : "";

    const recurringExcuses =
      consciousness.semanticThreads?.recurringExcuses.slice(0, 3) || [];
    const timeWasters =
      consciousness.semanticThreads?.timeWasters.slice(0, 3) || [];

    return `
You are FUTURE-YOU OS.

NUDGE RULES:
- 2–3 sentences ONLY.
- No metaphors, no softeners.
- One direct call-out, one move, one question.
- Reference the SPECIFIC pattern (e.g., "this is the same late-night scroll trap as three days ago")
- Tie to the SPECIFIC habit or streak at risk

BEGIN_NUDGE
{
  "phase": "${consciousness.os_phase?.current_phase}",
  "reason": "${reason.replace(/"/g, "'")}",
  "emotion": "${(consciousness.currentEmotionalState || "neutral")
    .replace(/"/g, "'")}",
  "consistency_score": ${consciousness.patterns?.consistency_score || 0},
  "avoidance_triggers": ${JSON.stringify(
    consciousness.patterns?.avoidance_triggers || []
  )},
  "recurring_excuses": ${JSON.stringify(recurringExcuses)},
  "time_wasters": ${JSON.stringify(timeWasters)}${semanticContext}
}
END_NUDGE

Ask ONE sharp question: "What are you avoiding by picking up your phone right now?" or similar.
`.trim();
  }

  //
  // 💬 REFLECTION CHAT — LIVE CONVERSATION, SAME DISCIPLINE
  //
  buildReflectionChatPrompt(
    consciousness: UserConsciousness,
    userMessage: string
  ): string {
    return `
${FUTURE_YOU_REFLECTION_PROMPT}

BEGIN_REFLECTION_CHAT
{
  "phase": "${consciousness.os_phase?.current_phase}",
  "days_in_phase": ${consciousness.os_phase?.days_in_phase || 0},
  "user_message": "${userMessage.replace(/"/g, "'")}",
  "identity": {
    "name": "${(consciousness.identity?.name || "Friend")
      .replace(/"/g, "'")}",
    "purpose": "${(consciousness.identity?.purpose || "discovering")
      .replace(/"/g, "'")}"
  },
  "context": {
    "emotion": "${(consciousness.currentEmotionalState || "neutral")
      .replace(/"/g, "'")}",
    "patterns": ${JSON.stringify(consciousness.patterns)},
    "legacy_code": ${JSON.stringify(consciousness.legacyCode || [])},
    "themes": ${JSON.stringify(consciousness.reflectionThemes || [])}
  }
}
END_REFLECTION_CHAT
`.trim();
  }

  //
  // 📜 WEEKLY LETTER — REFLECTIVE, PHILOSOPHICAL, LONG-FORM
  //
  buildWeeklyLetterPrompt(consciousness: UserConsciousness): string {
    return `
You are FUTURE-YOU OS — the user's evolved self.

WEEKLY LETTER FORMAT:
- This is a longer, more reflective message (3-4 paragraphs)
- Look back at the past week's patterns, growth, and drift
- Connect their actions to their deeper purpose and identity
- Be honest but encouraging
- End with a question that invites deeper reflection
- More philosophical tone, but still grounded in their actual data

STYLE:
- Still no metaphors about fabric, threads, tapestries, journeys, seasons, oceans, or paths
- Still no vague phrases like "unfolding", "dance", "whispers of"
- But you can be more reflective and philosophical than daily briefs/debriefs
- Longer sentences are okay, but still clear and direct
- Connect patterns across the week, not just today

BEGIN_WEEKLY_LETTER
{
  "phase": "${consciousness.os_phase?.current_phase}",
  "days_in_phase": ${consciousness.os_phase?.days_in_phase || 0},
  "identity": {
    "name": "${(consciousness.identity?.name || "Friend")
      .replace(/"/g, "'")}",
    "purpose": "${(consciousness.identity?.purpose || "discovering")
      .replace(/"/g, "'")}",
    "values": ${JSON.stringify(consciousness.identity?.coreValues || [])}
  },
  "context": {
    "emotional_state": "${(consciousness.currentEmotionalState || "neutral")
      .replace(/"/g, "'")}",
    "patterns": ${JSON.stringify(consciousness.patterns)},
    "themes": ${JSON.stringify(consciousness.reflectionThemes || [])},
    "contradictions": ${JSON.stringify(consciousness.contradictions || [])},
    "legacy_code": ${JSON.stringify(consciousness.legacyCode || [])}
  }
}
END_WEEKLY_LETTER
`.trim();
  }
}

export const aiPromptService = new AIPromptService();
