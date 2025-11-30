import { prisma } from "../utils/db";
import { memoryService } from "./memory.service";
import { semanticMemory } from "./semanticMemory.service";
import OpenAI from "openai";

const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o";

function getOpenAIClient() {
  if (process.env.NODE_ENV === "build" || process.env.RAILWAY_ENVIRONMENT === "build") return null;
  if (!process.env.OPENAI_API_KEY) return null;
  return new OpenAI({ apiKey: process.env.OPENAI_API_KEY.trim() });
}

export type AIPhase = "observer" | "architect" | "oracle";

export interface TimeWindow {
  time: string;
  description: string;
  frequency: number;
}

export interface Protocol {
  text: string;
  worked_count: number;
  last_used: Date;
}

export interface BehaviorPatterns {
  drift_windows: TimeWindow[];
  consistency_score: number;
  avoidance_triggers: string[];
  return_protocols: Protocol[];
  last_analyzed: Date;
}

export interface ReflectionHistory {
  themes: string[];
  emotional_arc: "ascending" | "flat" | "descending";
  depth_score: number;
}

export interface ArchitectData {
  structural_integrity_score: number;
  system_faults: Array<{ type: string; detected_at: Date; frequency: number }>;
  return_protocols: Protocol[];
  focus_pillars: string[];
  drag_map: Record<string, { severity: number; times: string[] }>;
}

export interface OracleData {
  legacy_code: string[];
  self_knowledge_journal: string[];
  meaning_graph: {
    core_motivations: string[];
    values_ranking: string[];
  };
  impact_theme?: string;
}

export interface OSPhase {
  current_phase: AIPhase;
  started_at: Date;
  days_in_phase: number;
  phase_transitions: Array<{ from: AIPhase; to: AIPhase; at: Date }>;
}

export interface SemanticThreads {
  recentHighlights: string[]; // last N important memories
  recurringExcuses: string[]; // phrases user repeats (time wasting / failure reasons)
  timeWasters: string[]; // e.g. "YouTube spiral", "doomscroll", etc
  emotionalContradictions: string[]; // "says X but does Y"
}

export interface HabitCompletionData {
  title: string;
  completedAt: Date;
  streak: number;
}

export interface ProductivityEvidence {
  last7Days: {
    completed: number;
    total: number;
    completionRate: number;
  };
  today: {
    completed: number;
    total: number;
    completions: HabitCompletionData[];
  };
  activeStreaks: Array<{ habitTitle: string; streak: number }>;
  recentWins: string[]; // Last few completed habit names
}

export interface UserConsciousness {
  identity: {
    name: string;
    age: number | null;
    purpose: string | null;
    coreValues: string[];
    vision: string | null;
    discoveryCompleted: boolean;
    createdAt?: Date;
  };

  patterns: BehaviorPatterns;
  reflectionHistory: ReflectionHistory;

  recentConversation: any[];
  currentEmotionalState: string;
  contradictions: string[];

  phase: AIPhase;
  os_phase: OSPhase;
  tone: string;
  nextEvolution: string;

  architect?: ArchitectData;
  oracle?: OracleData;

  reflectionThemes: string[];
  legacyCode: string[];

  // NEW: Semantic memory threads
  semanticThreads?: SemanticThreads;
  
  // NEW: Actual habit productivity data
  productivityEvidence?: ProductivityEvidence;
}

export interface VoiceIntensity {
  curiosity?: number;
  gentleness?: number;
  directness?: number;
  precision?: number;
  authority?: number;
  empathy?: number;
  stillness?: number;
  wisdom?: number;
  mystery?: number;
}

export class MemoryIntelligenceService {
  // ============================================================
  // 🧠 Build User Consciousness
  // ============================================================
  async buildUserConsciousness(userId: string): Promise<UserConsciousness> {
    const [user, facts, identity] = await Promise.all([
      prisma.user.findUnique({ where: { id: userId } }),
      prisma.userFacts.findUnique({ where: { userId } }),
      memoryService.getIdentityFacts(userId),
    ]);

    const factsData = (facts?.json as any) || {};
    const createdAt = user?.createdAt || new Date();

    const os_phase = this.getOrInitializePhase(factsData, createdAt);
    const phase = this.determinePhase(factsData, identity, createdAt);

    const patterns: BehaviorPatterns = factsData.behaviorPatterns || {
      drift_windows: [],
      consistency_score: 0,
      avoidance_triggers: [],
      return_protocols: [],
      last_analyzed: new Date(),
    };

    const reflectionHistory: ReflectionHistory = factsData.reflectionHistory || {
      themes: [],
      emotional_arc: "flat",
      depth_score: 0,
    };

    // NEW: Build semantic threads from vector memory
    const semanticThreads = await this.buildSemanticThreads(userId);
    
    // NEW: Extract actual productivity evidence
    const productivityEvidence = await this.extractProductivityEvidence(userId);

    return {
      identity: {
        name: identity.name,
        age: identity.age,
        purpose: identity.purpose,
        coreValues: identity.coreValues,
        vision: identity.vision,
        discoveryCompleted: identity.discoveryCompleted,
        createdAt,
      },
      patterns,
      reflectionHistory,
      recentConversation: [],
      currentEmotionalState: "balanced",
      contradictions: [],
      phase,
      os_phase,
      tone: user?.tone || "balanced",
      nextEvolution: this.predictNextGrowth(patterns, reflectionHistory),
      architect: factsData.architect,
      oracle: factsData.oracle,
      reflectionThemes: reflectionHistory.themes,
      legacyCode: factsData.oracle?.legacy_code || [],
      semanticThreads,
      productivityEvidence,
    };
  }

  // ============================================================
  // 🧵 Build Semantic Threads from Vector Memory
  // ============================================================
  private async buildSemanticThreads(userId: string): Promise<SemanticThreads> {
    try {
      // Fetch recent memories from semantic store
      const recentMemories = await semanticMemory.getRecentMemories({
        userId,
        limit: 20,
      });

      if (recentMemories.length === 0) {
        return {
          recentHighlights: [],
          recurringExcuses: [],
          timeWasters: [],
          emotionalContradictions: [],
        };
      }

      // Extract patterns
      const highlights = recentMemories
        .filter((m) => m.metadata?.importance >= 4)
        .map((m) => m.text.substring(0, 100))
        .slice(0, 5);

      const recurringExcuses = this.extractRecurringPhrases(
        recentMemories.map((m) => m.text),
        [
          "didn't have time",
          "was tired",
          "wasn't in the mood",
          "couldn't be bothered",
          "too busy",
          "didn't feel like it",
          "later",
          "tomorrow",
        ]
      );

      const timeWasters = this.extractRecurringPhrases(
        recentMemories.map((m) => m.text),
        [
          "scroll",
          "scrolling",
          "youtube",
          "tiktok",
          "instagram",
          "social media",
          "netflix",
          "gaming",
          "binge",
          "doom",
          "wasted time",
        ]
      );

      const emotionalContradictions = this.detectContradictoryPatterns(recentMemories);

      return {
        recentHighlights: highlights,
        recurringExcuses,
        timeWasters,
        emotionalContradictions,
      };
    } catch (err) {
      console.warn("⚠️ Failed to build semantic threads:", err);
      return {
        recentHighlights: [],
        recurringExcuses: [],
        timeWasters: [],
        emotionalContradictions: [],
      };
    }
  }

  /**
   * Extract recurring phrases from memory texts
   */
  private extractRecurringPhrases(texts: string[], keywords: string[]): string[] {
    const found: Record<string, number> = {};

    for (const text of texts) {
      const lower = text.toLowerCase();
      for (const keyword of keywords) {
        if (lower.includes(keyword)) {
          found[keyword] = (found[keyword] || 0) + 1;
        }
      }
    }

    // Return phrases that appear 2+ times, sorted by frequency
    return Object.entries(found)
      .filter(([, count]) => count >= 2)
      .sort(([, a], [, b]) => b - a)
      .map(([phrase]) => phrase)
      .slice(0, 5);
  }

  /**
   * Detect behavioral contradictions from memories
   */
  private detectContradictoryPatterns(memories: any[]): string[] {
    // Look for patterns like: "I want X" but behavior shows "not doing X"
    const contradictions: string[] = [];
    const texts = memories.map((m) => m.text);

    // Simple heuristic: find "want" statements and check for failure patterns
    for (const text of texts) {
      const lower = text.toLowerCase();
      if (
        (lower.includes("want") || lower.includes("need") || lower.includes("should")) &&
        (lower.includes("but") || lower.includes("didn't") || lower.includes("missed"))
      ) {
        // Extract a snippet
        const snippet = text.substring(0, 80) + (text.length > 80 ? "..." : "");
        contradictions.push(snippet);
        if (contradictions.length >= 3) break;
      }
    }

    return contradictions;
  }

  // ============================================================
  // 📊 Extract Productivity Evidence from Habit Actions  
  // ============================================================
  private async extractProductivityEvidence(userId: string): Promise<ProductivityEvidence> {
    try {
      // Get user's habits
      const habits = await prisma.habit.findMany({
        where: { userId },
        select: { id: true, title: true, streak: true },
      });

      if (habits.length === 0) {
        return {
          last7Days: { completed: 0, total: 0, completionRate: 0 },
          today: { completed: 0, total: 0, completions: [] },
          activeStreaks: [],
          recentWins: [],
        };
      }

      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const sevenDaysAgo = new Date(today);
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      // Get habit actions from last 7 days
      const recentActions = await prisma.event.findMany({
        where: {
          userId,
          type: "habit_action",
          ts: { gte: sevenDaysAgo },
        },
        orderBy: { ts: "desc" },
      });

      // Calculate 7-day stats
      const completedLast7Days = recentActions.filter(
        (e) => (e.payload as any)?.completed === true
      );
      const totalActionsLast7Days = recentActions.length;
      const completionRate =
        totalActionsLast7Days > 0
          ? Math.round((completedLast7Days.length / totalActionsLast7Days) * 100)
          : 0;

      // Get today's completions
      const todayActions = recentActions.filter((e) => {
        const actionDate = new Date(e.ts);
        return actionDate >= today;
      });

      const todayCompletions = todayActions.filter(
        (e) => (e.payload as any)?.completed === true
      );

      // Map habit IDs to titles
      const habitMap = new Map(habits.map((h) => [h.id, h]));

      const todayCompletionData: HabitCompletionData[] = todayCompletions
        .map((e) => {
          const payload = e.payload as any;
          const habit = habitMap.get(payload.habitId);
          if (!habit) return null;
          return {
            title: habit.title,
            completedAt: new Date(e.ts),
            streak: this.calculateStreakFromEvents(payload.habitId, recentActions),
          };
        })
        .filter((c): c is HabitCompletionData => c !== null)
        .slice(0, 10); // Limit to 10 most recent

      // Calculate REAL streaks from Events (not from Habit table which is stale)
      const activeStreaks = this.calculateAllStreaks(habits, recentActions)
        .filter((s) => s.streak >= 3)
        .sort((a, b) => b.streak - a.streak)
        .slice(0, 5); // Top 5 streaks

      // Recent wins (last 5 completed habits with actual names)
      const recentWins = completedLast7Days
        .slice(0, 5)
        .map((e) => {
          const payload = e.payload as any;
          const habit = habitMap.get(payload.habitId);
          return habit?.title || null;
        })
        .filter((title): title is string => title !== null);

      return {
        last7Days: {
          completed: completedLast7Days.length,
          total: totalActionsLast7Days,
          completionRate,
        },
        today: {
          completed: todayCompletions.length,
          total: todayActions.length,
          completions: todayCompletionData,
        },
        activeStreaks,
        recentWins,
      };
    } catch (err) {
      console.warn("⚠️ Failed to extract productivity evidence:", err);
      return {
        last7Days: { completed: 0, total: 0, completionRate: 0 },
        today: { completed: 0, total: 0, completions: [] },
        activeStreaks: [],
        recentWins: [],
      };
    }
  }

  /**
   * Calculate current streak for a habit from Event data
   */
  private calculateStreakFromEvents(habitId: string, events: any[]): number {
    const habitEvents = events
      .filter((e) => (e.payload as any)?.habitId === habitId)
      .sort((a, b) => new Date(b.ts).getTime() - new Date(a.ts).getTime());

    let streak = 0;
    let currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0);

    for (const event of habitEvents) {
      const eventDate = new Date(event.ts);
      eventDate.setHours(0, 0, 0, 0);
      
      const payload = event.payload as any;
      
      // Check if this event is from today or consecutive days
      const daysDiff = Math.floor((currentDate.getTime() - eventDate.getTime()) / (1000 * 60 * 60 * 24));
      
      if (daysDiff === streak && payload.completed === true) {
        streak++;
      } else if (daysDiff > streak) {
        break; // Streak broken
      }
    }

    return streak;
  }

  /**
   * Calculate streaks for all habits from Event data
   */
  private calculateAllStreaks(habits: any[], events: any[]): Array<{ habitTitle: string; streak: number }> {
    return habits.map((habit) => ({
      habitTitle: habit.title,
      streak: this.calculateStreakFromEvents(habit.id, events),
    }));
  }

  /**
   * Summary of behavioral contradictions for prompts
   */
  summarizeBehaviouralContradictions(c: UserConsciousness): string[] {
    const summary: string[] = [];

    if (!c.semanticThreads) return summary;

    // Time-wasting vs goals
    if (c.semanticThreads.timeWasters.length > 0 && c.semanticThreads.recurringExcuses.includes("didn't have time")) {
      const waster = c.semanticThreads.timeWasters[0];
      summary.push(`You say you don't have time, but you lose hours to ${waster}.`);
    }

    // Recurring excuses
    if (c.semanticThreads.recurringExcuses.length >= 2) {
      const excuses = c.semanticThreads.recurringExcuses.slice(0, 2).join('", "');
      summary.push(`Your recurring excuses: "${excuses}".`);
    }

    // Emotional contradictions
    if (c.semanticThreads.emotionalContradictions.length > 0) {
      summary.push(c.semanticThreads.emotionalContradictions[0]);
    }

    return summary;
  }

  // ============================================================
  // 🔥 Extract User Patterns
  // ============================================================
  async extractPatternsFromEvents(userId: string): Promise<void> {
    const since = new Date(Date.now() - 30 * 86400000);

    const events = await prisma.event.findMany({
      where: { userId, ts: { gte: since } },
      orderBy: { ts: "desc" },
    });

    const habitTicks = events.filter((e) => e.type === "habit_tick");
    const drift_windows = this.findDriftWindows(habitTicks);
    const consistency_score = this.calculateConsistency(habitTicks);

    // Include reflection_answer events in chat analysis
    const chatMessages = events.filter(
      (e) => e.type === "chat_message" || e.type === "reflection_answer"
    );
    const reflectionThemes = await this.extractThemesWithAI(chatMessages);
    const depth_score = this.scoreReflectionDepth(chatMessages);

    const avoidance_triggers = this.detectAvoidance(events);
    const return_protocols = this.extractReturnProtocols(events);

    await memoryService.upsertFacts(userId, {
      behaviorPatterns: {
        drift_windows,
        consistency_score,
        avoidance_triggers,
        return_protocols,
        last_analyzed: new Date(),
      },
      reflectionHistory: {
        themes: reflectionThemes,
        depth_score,
        emotional_arc: this.detectEmotionalArc(chatMessages),
      },
    });
  }

  // ============================================================
  // 🎭 Should Transition Phase?
  // ============================================================
  shouldTransitionPhase(c: UserConsciousness): boolean {
    if (c.phase === "observer") {
      return (
        c.identity.discoveryCompleted &&
        c.reflectionHistory.themes.length >= 3 &&
        c.reflectionHistory.depth_score >= 4
      );
    }

    if (c.phase === "architect") {
      return (
        c.os_phase.days_in_phase >= 30 &&
        c.patterns.consistency_score >= 60 &&
        c.reflectionHistory.depth_score >= 7
      );
    }

    return false;
  }

  // ============================================================
  // 🔥 Phase Logic (PUBLIC, correct signature, 3 args)
  // ============================================================
  determinePhase(factsData: any, identity: any, createdAt: Date): AIPhase {
    const days = Math.floor((Date.now() - createdAt.getTime()) / 86400000);

    const depth = factsData.reflectionHistory?.depth_score || 0;
    const discovery = identity.discoveryCompleted;
    const current = factsData.os_phase?.current_phase;

    // OBSERVER
    if (!discovery || days < 14) return "observer";

    // ARCHITECT
    if (current === "architect" || (days >= 14 && depth >= 5)) {
      if (current === "architect") {
        const daysInPhase = factsData.os_phase?.days_in_phase || 0;
        const consistency = factsData.behaviorPatterns?.consistency_score || 0;

        if (daysInPhase >= 30 && depth >= 7 && consistency >= 60) return "oracle";
      }
      return "architect";
    }

    // ORACLE
    if (current === "oracle" || (days >= 60 && depth >= 7)) return "oracle";

    return current || "observer";
  }

  // ============================================================
  // 📈 Growth Prediction
  // ============================================================
  predictNextGrowth(patterns: BehaviorPatterns, r: ReflectionHistory): string {
    if (patterns.consistency_score > 70 && r.themes.length < 3) return "deepen_meaning";
    if (patterns.avoidance_triggers.length > 3) return "confront_avoidance";
    if (r.depth_score < 5) return "deepen_reflection";
    if (patterns.drift_windows.length > 2) return "build_structure";
    return "maintain_momentum";
  }

  // ============================================================
  // 🎚 Voice Intensity
  // ============================================================
  determineVoiceIntensity(c: UserConsciousness): any {
    if (c.phase === "observer") {
      const p = Math.min(c.reflectionHistory.themes.length / 10, 1);
      return { curiosity: 1 - p * 0.3, gentleness: 0.9, directness: p * 0.4 };
    }

    if (c.phase === "architect") {
      const i = c.patterns.consistency_score / 100;
      return { precision: 0.8 + i * 0.2, authority: 0.6 + i * 0.3, empathy: 0.5 - i * 0.2 };
    }

    if (c.phase === "oracle") {
      const m = Math.min(c.os_phase.days_in_phase / 60, 1);
      return { stillness: 0.5 + m * 0.5, wisdom: 0.7 + m * 0.3, mystery: m * 0.6 };
    }

    return {};
  }

  // ============================================================
  // Helper Functions
  // ============================================================
  private getOrInitializePhase(factsData: any, createdAt: Date): OSPhase {
    if (factsData.os_phase) {
      const days = Math.floor(
        (Date.now() - new Date(factsData.os_phase.started_at).getTime()) / 86400000
      );
      return { ...factsData.os_phase, days_in_phase: days };
    }

    return {
      current_phase: "observer",
      started_at: createdAt,
      days_in_phase: Math.floor((Date.now() - createdAt.getTime()) / 86400000),
      phase_transitions: [],
    };
  }

  private findDriftWindows(habitTicks: any[]): TimeWindow[] {
    const hours: Record<number, { total: number; completed: number }> = {};

    for (const t of habitTicks) {
      const h = new Date(t.ts).getHours();
      if (!hours[h]) hours[h] = { total: 0, completed: 0 };
      hours[h].total++;
      if ((t.payload as any)?.completed) hours[h].completed++;
    }

    return Object.entries(hours)
      .map(([hourStr, counts]) => {
        const rate = counts.completed / counts.total;
        if (rate < 0.5 && counts.total >= 3) {
          return {
            time: `${hourStr}:00`,
            description: `Low completion rate (${Math.round(rate * 100)}%)`,
            frequency: counts.total,
          };
        }
        return null;
      })
      .filter(Boolean)
      .sort((a: any, b: any) => b.frequency - a.frequency)
      .slice(0, 3);
  }

  private calculateConsistency(habitTicks: any[]) {
    if (habitTicks.length === 0) return 0;
    const completed = habitTicks.filter((t) => (t.payload as any)?.completed).length;
    return Math.round((completed / habitTicks.length) * 100);
  }

  private async extractThemesWithAI(messages: any[]) {
    if (!messages.length || messages.length < 3) return [];

    const openai = getOpenAIClient();
    if (!openai) return [];

    try {
      const text = messages
        .slice(0, 20)
        .map((m) => (m.payload as any)?.text || "")
        .filter((t) => t.length > 20)
        .join("\n");

      if (!text) return [];

      const completion = await openai.chat.completions.create({
        model: OPENAI_MODEL,
        max_completion_tokens: 200,
        messages: [
          { role: "system", content: "Extract 3–5 themes. Output ONLY JSON array." },
          { role: "user", content: text },
        ],
      });

      const raw = completion.choices[0]?.message?.content?.trim() || "[]";
      return JSON.parse(raw.replace(/```json|```/g, "")).slice(0, 5);
    } catch {
      return [];
    }
  }

  private scoreReflectionDepth(messages: any[]) {
    if (messages.length === 0) return 0;
    const avg =
      messages.reduce((sum, m) => sum + ((m.payload as any)?.text?.length || 0), 0) /
      messages.length;
    const lengthScore = Math.min(avg / 100, 5);
    const freqScore = Math.min(messages.length / 10, 5);
    return Math.round(lengthScore + freqScore);
  }

  private detectAvoidance(events: any[]) {
    const map: Record<string, number> = {};
    for (const ev of events) {
      if (ev.type === "habit_action" && !(ev.payload as any)?.completed) {
        const id = (ev.payload as any)?.habitId;
        if (id) map[id] = (map[id] || 0) + 1;
      }
    }
    return Object.entries(map)
      .filter(([, count]) => count >= 5)
      .map(([id]) => id);
  }

  private extractReturnProtocols(events: any[]) {
    const out: Protocol[] = [];
    const refs = events
      .filter((e) => e.type === "chat_message" || e.type === "debrief" || e.type === "reflection_answer")
      .slice(0, 10);

    for (const r of refs) {
      const text = (r.payload as any)?.text || (r.payload as any)?.answer || "";
      if (
        text.includes("came back") ||
        text.includes("returned") ||
        text.includes("got back")
      ) {
        out.push({
          text: text.slice(0, 100),
          worked_count: 1,
          last_used: r.ts,
        });
      }
    }

    return out.slice(0, 5);
  }

  private detectEmotionalArc(messages: any[]): "ascending" | "flat" | "descending" {
    if (messages.length < 5) return "flat";

    let p = 0;
    let n = 0;

    const pos = ["better", "great", "progress", "improved", "good"];
    const neg = ["worse", "struggling", "failed", "hard", "difficult"];

    const recent = messages.slice(0, 10);

    for (const m of recent) {
      const text = ((m.payload as any)?.text || "").toLowerCase();
      for (const w of pos) if (text.includes(w)) p++;
      for (const w of neg) if (text.includes(w)) n++;
    }

    if (p > n * 1.5) return "ascending";
    if (n > p * 1.5) return "descending";
    return "flat";
  }
}

export const memoryIntelligence = new MemoryIntelligenceService();
