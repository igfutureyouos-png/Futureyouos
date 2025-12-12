// =============================================================================
// DEEP USER MODEL SERVICE (Option A - Clean, Safe, Claude-Style)
// =============================================================================
// Single source of truth for the 7-layer DeepUserModel used by:
// - memory-synthesis.service.ts
// - coach-engine.service.ts
// - pattern-learning.worker.ts
// - ai.service.v2.ts
//
// This version is:
// - Predictable
// - Typesafe
// - Easy to extend
// - Not over-crazy: simple heuristics, no insane ML
// =============================================================================

import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import { memoryService } from "./memory.service";

// If you have this service already, keep the import.
// It's not strictly used here but kept for future extensions.
import { memoryIntelligence } from "./memory-intelligence.service";

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

// -----------------------------------------------------------------------------
// Layer 1: Identity
// -----------------------------------------------------------------------------

export interface UserIdentity {
  userId: string;
  name: string;
  email: string | null;
  timezone: string;
  age: number | null;
  purpose: string | null;
  values: string[];
  vision: string | null;
  burningQuestion: string | null;
  discoveryCompleted: boolean;
  daysInSystem: number;
  createdAt: Date;
}

// -----------------------------------------------------------------------------
// Layer 2: Behavior
// -----------------------------------------------------------------------------

export interface HabitSummary {
  id: string;
  title: string;
  streak: number;
  lastTick: Date | null;
  completionRate7d: number;
  completionRate30d: number;
  scheduledTime: string | null;
  importance: number; // 1–5
}

export interface UserBehavior {
  habits: HabitSummary[];
  totalHabits: number;
  activeHabits: number; // streak > 0
  dormantHabits: number; // streak = 0 but has been ticked before
  neverStartedHabits: number; // never ticked
  longestCurrentStreak: number;
  longestStreakHabit: string | null;
  last7DaysRate: number;
  last30DaysRate: number;
  daysSinceLastAction: number;
  mostActiveHours: number[]; // hours with highest completions
  leastActiveHours: number[]; // hours with lowest completions
}

// -----------------------------------------------------------------------------
// Layer 3: Patterns
// -----------------------------------------------------------------------------

export interface DriftWindow {
  hourOfDay: number;
  dayOfWeek: number | null; // null = any day
  completionRate: number;
  sampleSize: number;
  description: string;
}

export interface DayOfWeekPattern {
  day: number; // 0-6
  dayName: string;
  completionRate: number;
  avgCompletions: number;
  isStrongDay: boolean;
  isWeakDay: boolean;
}

export type EngagementPattern =
  | "daily_engaged" // opens + completes most days
  | "weekend_warrior"
  | "weekday_warrior"
  | "sporadic"
  | "fading"
  | "ghost"
  | "new_user";

export interface UserPatterns {
  driftWindows: DriftWindow[];
  dayOfWeekPatterns: DayOfWeekPattern[];
  strongestDay: DayOfWeekPattern | null;
  weakestDay: DayOfWeekPattern | null;
  engagementPattern: EngagementPattern;
  avoidedHabits: string[]; // habit IDs consistently missed
  consistencyScore: number; // 0–100
}

// -----------------------------------------------------------------------------
// Layer 4: Contradictions
// -----------------------------------------------------------------------------

export interface Contradiction {
  id: string;
  description: string;
  evidence: string;
  severity: number; // 1–5
  status: "active" | "resolved";
  discoveredAt: Date;
  lastUpdatedAt: Date;
}

export interface ContradictionLayer {
  active: Contradiction[];
  resolved: Contradiction[];
  primaryContradiction: Contradiction | null;
}

// -----------------------------------------------------------------------------
// Layer 5: Psychology
// -----------------------------------------------------------------------------

export interface ShameSensitivity {
  score: number; // 0–1
  ghostsAfterMissedStreak: boolean;
  ghostsAfterConfrontation: boolean;
  deletesHabitsAfterFailure: boolean;
  respondsToSoftReentry: boolean;
  ignoresAfterMultipleNudges: boolean;
  maxMessageIntensity: number; // 1–10
  requiresSoftLanding: boolean;
  confidence: number; // 0–1
  dataPoints: number;
}

export interface RecurringExcuse {
  phrase: string;
  frequency: number;
  lastUsedAt: Date | null;
  typicallyFollowedBySlip: boolean;
}

export interface LimitingNarrative {
  narrative: string;
  sentiment: "limiting" | "empowering" | "neutral";
  frequency: number;
  challenged: boolean;
  lastSeenAt: Date | null;
}

export type MotivationStyle =
  | "progress"
  | "fear"
  | "identity"
  | "social"
  | "competition"
  | "unknown";

export interface UserPsychology {
  shameSensitivity: ShameSensitivity;
  recurringExcuses: RecurringExcuse[];
  timeWasters: string[];
  limitingNarratives: LimitingNarrative[];
  motivationStyle: MotivationStyle;
}

// -----------------------------------------------------------------------------
// Layer 6: Predictions
// -----------------------------------------------------------------------------

export interface RiskFactor {
  key: string;
  description: string;
  weight: number; // 0–1
  direction: "up" | "down" | "neutral";
}

export interface SlipRiskAssessment {
  probability: number; // 0–1
  level: "low" | "medium" | "high" | "critical";
  factors: RiskFactor[];
  primaryFactors: string[];
  estimatedTimeToSlip: number | null; // hours
  trend: "increasing" | "stable" | "decreasing";
}

export interface StreakRisk {
  habitId: string;
  habitTitle: string;
  streak: number;
  riskLevel: "low" | "medium" | "high";
  reason: string;
}

export interface UserPredictions {
  slipRisk: SlipRiskAssessment;
  engagementRisk: SlipRiskAssessment;
  streakRisks: StreakRisk[];
}

// -----------------------------------------------------------------------------
// Layer 7: Identity Arc
// -----------------------------------------------------------------------------

export interface ArcMilestone {
  id: string;
  type: string;
  description: string;
  achievedAt: Date;
  significance: number; // 1–5
}

export interface UserArc {
  phase: "observer" | "architect" | "oracle";
  daysInPhase: number;
  milestones: ArcMilestone[];
  nextMilestone: string | null;
}

// -----------------------------------------------------------------------------
// Learned Model (Nightly + Real-Time Learning)
// -----------------------------------------------------------------------------

export interface RecoveryStyle {
  type: "gradual" | "sudden" | "oscillating";
  avgRecoveryDays: number;
  needsSmallWins: boolean;
  crashRiskAfterRestart: number;
  evidence: string[];
}

export interface ChallengeResponse {
  type: "rise" | "retreat" | "freeze";
  confidence: number;
  evidence: string[];
}

export interface CelebrationTrap {
  type: "coast" | "accelerate" | "maintain";
  riskDaysAfterStreak: number[];
  evidence: string[];
}

export interface SlipSignature {
  warningBehaviors: string[];
  typicalExcuses: string[];
  avgGhostDuration: number;
  returnTrigger: string | null;
  confidence: number;
}

export interface MotivationProfile {
  primary: "progress" | "fear" | "identity" | "social" | "competition" | "unknown";
  secondary: string | null;
  evidence: string[];
}

export interface BehavioralFingerprint {
  recoveryStyle: RecoveryStyle;
  challengeResponse: ChallengeResponse;
  celebrationTrap: CelebrationTrap;
  slipSignature: SlipSignature;
  motivationProfile: MotivationProfile;
  dataPoints: number;
  lastUpdated: Date;
}

export interface TriggerChainPatternStep {
  eventType: string;
  condition: string; // free-form description
  required: boolean;
  windowHours: number;
}

export interface TriggerChain {
  id: string;
  name: string;
  pattern: TriggerChainPatternStep[];
  occurrences: number;
  ledToSlip: number;
  slipProbability: number;
  avgTimeToSlip: number;
  interventionPoint: number;
  recommendedIntervention: "soft_nudge" | "direct_nudge" | "brace_message" | "none";
  firstDetected: Date;
  lastOccurred: Date;
  confidence: number;
}

export interface TriggerChainWarning {
  chainId: string;
  chainName: string;
  currentStage: number;
  totalStages: number;
  estimatedRisk: "low" | "medium" | "high" | "critical";
  nextEventExpectedBy: Date | null;
}

export interface MessagePattern {
  messageType: "brief" | "nudge" | "debrief" | "letter";
  avgOpenRate: number;
  avgTimeToOpen: number;
  avgReadDepth: number;
  responseRate: number;
  effectivenessByIntensity: Array<{
    intensity: number;
    effectiveness: number;
  }>;
  optimalIntensity: number;
  optimalTimeOfDay: string | null;
}

export interface CommitmentRecord {
  id: string;
  text: string;
  extractedAction: string | null;
  extractedTime: string | null;
  madeAt: Date;
  madeIn: "chat" | "brief" | "nudge" | "debrief" | "other";
  dueBy: Date | null;
  status: "pending" | "kept" | "broken";
  wasExplicit: boolean;
  followUpSent: boolean;
  resolvedAt?: Date | null;
  keptEvidenceEventId?: string | null;
}

export interface LearnedUserModel {
  fingerprint: BehavioralFingerprint | null;
  shameSensitivity: ShameSensitivity | null;
  triggerChains: TriggerChain[];
  messagePatterns: MessagePattern[];
  commitments: CommitmentRecord[];
  excuses: RecurringExcuse[];
  narratives: LimitingNarrative[];
  dataPointsUsed: number;
  confidenceLevel: "insufficient" | "low" | "medium" | "high";
  milestones: ArcMilestone[];
}

// -----------------------------------------------------------------------------
// Root DeepUserModel
// -----------------------------------------------------------------------------

export interface DeepUserModel {
  identity: UserIdentity;
  behavior: UserBehavior;
  patterns: UserPatterns;
  contradictions: ContradictionLayer;
  psychology: UserPsychology;
  predictions: UserPredictions;
  arc: UserArc;
  learned: LearnedUserModel | null;
  activeTriggerChainWarning: TriggerChainWarning | null;
  modelConfidence: "insufficient" | "low" | "medium" | "high";
}

// =============================================================================
// INTERNAL HELPERS
// =============================================================================

const DEEP_MODEL_CACHE_TTL_SECONDS = 60 * 5; // 5 minutes
const LEARNED_MODEL_CACHE_TTL_SECONDS = 60 * 60 * 24; // 24 hours

function dayNameFromIndex(day: number): string {
  return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][day] ?? "Unknown";
}

function clamp(num: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, num));
}

function riskLevelFromProbability(p: number): SlipRiskAssessment["level"] {
  if (p >= 0.8) return "critical";
  if (p >= 0.6) return "high";
  if (p >= 0.3) return "medium";
  return "low";
}

// =============================================================================
// SERVICE CLASS
// =============================================================================

class DeepUserModelService {
  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /**
   * Build the full DeepUserModel for a user.
   * Uses Redis caching (5 minutes) for performance.
   */
  async buildDeepUserModel(userId: string): Promise<DeepUserModel> {
    const cacheKey = `deep_model:${userId}`;
    const cached = await redis.get(cacheKey);
    if (cached) {
      try {
        return JSON.parse(cached) as DeepUserModel;
      } catch {
        // fall through
      }
    }

    const [user, factsRow, habits, events, completions] = await Promise.all([
      prisma.user.findUnique({ where: { id: userId } }),
      prisma.userFacts.findUnique({ where: { userId } }),
      prisma.habit.findMany({ where: { userId } }),
      prisma.event.findMany({
        where: { userId },
        orderBy: { ts: "asc" },
      }),
      prisma.completion.findMany({ where: { userId } }),
    ]);

    if (!user) {
      throw new Error(`User ${userId} not found`);
    }

    const now = new Date();
    const createdAt = user.createdAt ?? now;
    const daysInSystem = Math.max(0, Math.floor((now.getTime() - createdAt.getTime()) / 86400000));

    // Parse stored facts JSON
    const factsJson = (factsRow?.json as any) || {};
    const storedLearned = (factsJson.learnedModel || null) as LearnedUserModel | null;

    // Layer 1: Identity
    const identity: UserIdentity = {
      userId,
      name: (factsJson.name as string) || (factsJson.identity?.name as string) || (user.email?.split("@")[0] ?? "Friend"),
      email: user.email,
      timezone: user.tz || "UTC",
      age: factsJson.age ?? factsJson.identity?.age ?? null,
      purpose: factsJson.purpose ?? null,
      values: Array.isArray(factsJson.values) ? factsJson.values : [],
      vision: factsJson.vision ?? null,
      burningQuestion: factsJson.burningQuestion ?? factsJson.identity?.burningQuestion ?? null,
      discoveryCompleted: Boolean(factsJson.discoveryCompleted),
      daysInSystem,
      createdAt,
    };

    // Layer 2: Behavior
    const behavior = await this.buildUserBehavior(userId, habits, completions, events);

    // Layer 3: Patterns
    const patterns = this.buildUserPatterns(behavior, completions);

    // Layer 4: Contradictions (simple, safe — mostly empty but extendable)
    const contradictions = this.buildContradictions(identity, behavior, patterns, factsJson);

    // Layer 5: Psychology
    const psychology = this.buildPsychology(storedLearned, factsJson);

    // Layer 6: Predictions
    const predictions = this.buildPredictions(behavior, psychology);

    // Layer 7: Arc
    const arc = this.buildUserArc(identity, storedLearned);

    // Learned model
    const learned = this.normalizeLearnedModel(storedLearned);

    // Confidence
    const modelConfidence = learned?.confidenceLevel ?? "insufficient";

    // Active trigger chain warning (simple: none for now, safe)
    const activeTriggerChainWarning: TriggerChainWarning | null = null;

    const model: DeepUserModel = {
      identity,
      behavior,
      patterns,
      contradictions,
      psychology,
      predictions,
      arc,
      learned,
      activeTriggerChainWarning,
      modelConfidence,
    };

    await redis.set(cacheKey, JSON.stringify(model), "EX", DEEP_MODEL_CACHE_TTL_SECONDS);
    return model;
  }

  /**
   * Get the stored LearnedUserModel (without recomputing everything).
   */
  async getLearnedModel(userId: string): Promise<LearnedUserModel | null> {
    const cacheKey = `learned_model:${userId}`;
    const cached = await redis.get(cacheKey);
    if (cached) {
      try {
        return JSON.parse(cached) as LearnedUserModel;
      } catch {
        // ignore parse error
      }
    }

    const factsRow = await prisma.userFacts.findUnique({ where: { userId } });
    const factsJson = (factsRow?.json as any) || {};
    const stored = (factsJson.learnedModel || null) as LearnedUserModel | null;
    const normalized = this.normalizeLearnedModel(stored);

    if (normalized) {
      await redis.set(cacheKey, JSON.stringify(normalized), "EX", LEARNED_MODEL_CACHE_TTL_SECONDS);
    }

    return normalized;
  }

  /**
   * Update the learned model (used by nightly PatternLearningWorker).
   */
  async updateLearnedModel(userId: string, updates: Partial<LearnedUserModel>): Promise<LearnedUserModel> {
    const existing = (await this.getLearnedModel(userId)) || this.emptyLearnedModel();
    const merged: LearnedUserModel = {
      ...existing,
      ...updates,
      // merge arrays if provided, otherwise keep existing
      triggerChains: updates.triggerChains ?? existing.triggerChains,
      messagePatterns: updates.messagePatterns ?? existing.messagePatterns,
      commitments: updates.commitments ?? existing.commitments,
      excuses: updates.excuses ?? existing.excuses,
      narratives: updates.narratives ?? existing.narratives,
      milestones: updates.milestones ?? existing.milestones,
      dataPointsUsed: updates.dataPointsUsed ?? existing.dataPointsUsed,
      confidenceLevel: updates.confidenceLevel ?? existing.confidenceLevel,
      fingerprint: updates.fingerprint ?? existing.fingerprint,
      shameSensitivity: updates.shameSensitivity ?? existing.shameSensitivity,
    };

    await this.persistLearnedModel(userId, merged);
    return merged;
  }

  /**
   * Learn an excuse in real-time (used from Chat, Nudge, etc).
   */
  async addExcuse(userId: string, phrase: string, followedBySlip: boolean = false): Promise<void> {
    const learned = (await this.getLearnedModel(userId)) || this.emptyLearnedModel();
    const existing = learned.excuses.find(e => e.phrase === phrase);

    if (existing) {
      existing.frequency += 1;
      existing.lastUsedAt = new Date();
      if (followedBySlip) existing.typicallyFollowedBySlip = true;
    } else {
      learned.excuses.push({
        phrase,
        frequency: 1,
        lastUsedAt: new Date(),
        typicallyFollowedBySlip: followedBySlip,
      });
    }

    await this.persistLearnedModel(userId, learned);
  }

  /**
   * Learn a narrative in real-time.
   */
  async addNarrative(
    userId: string,
    narrative: string,
    sentiment: "limiting" | "empowering" | "neutral"
  ): Promise<void> {
    const learned = (await this.getLearnedModel(userId)) || this.emptyLearnedModel();
    const existing = learned.narratives.find(n => n.narrative === narrative);

    if (existing) {
      existing.frequency += 1;
      existing.lastSeenAt = new Date();
      existing.sentiment = sentiment;
    } else {
      learned.narratives.push({
        narrative,
        sentiment,
        frequency: 1,
        challenged: false,
        lastSeenAt: new Date(),
      });
    }

    await this.persistLearnedModel(userId, learned);
  }

  /**
   * Add a commitment record (e.g., from chat "I'll do it tomorrow").
   */
  async addCommitment(userId: string, commitment: Omit<CommitmentRecord, "id" | "status"> & {
    status?: CommitmentRecord["status"];
  }): Promise<CommitmentRecord> {
    const learned = (await this.getLearnedModel(userId)) || this.emptyLearnedModel();

    const record: CommitmentRecord = {
      id: `commit_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      status: commitment.status ?? "pending",
      ...commitment,
    };

    learned.commitments.push(record);
    await this.persistLearnedModel(userId, learned);
    return record;
  }

  /**
   * Resolve a commitment (kept or broken).
   */
  async resolveCommitment(
    userId: string,
    commitmentId: string,
    kept: boolean,
    evidenceEventId?: string
  ): Promise<void> {
    const learned = (await this.getLearnedModel(userId)) || this.emptyLearnedModel();
    const commitment = learned.commitments.find(c => c.id === commitmentId);
    if (!commitment) return;

    commitment.status = kept ? "kept" : "broken";
    commitment.resolvedAt = new Date();
    if (kept && evidenceEventId) {
      commitment.keptEvidenceEventId = evidenceEventId;
    }

    await this.persistLearnedModel(userId, learned);
  }

  /**
   * Record a milestone in the user's arc.
   */
  async recordMilestone(
    userId: string,
    milestone: Omit<ArcMilestone, "id" | "achievedAt">
  ): Promise<ArcMilestone> {
    const learned = (await this.getLearnedModel(userId)) || this.emptyLearnedModel();

    const record: ArcMilestone = {
      id: `milestone_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      achievedAt: new Date(),
      ...milestone,
    };

    learned.milestones.push(record);
    await this.persistLearnedModel(userId, learned);
    return record;
  }

  // ---------------------------------------------------------------------------
  // INTERNAL BUILDERS
  // ---------------------------------------------------------------------------

  private async buildUserBehavior(
    userId: string,
    habits: any[],
    completions: any[],
    events: any[]
  ): Promise<UserBehavior> {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 86400000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 86400000);

    const completionByHabit = completions.reduce<Record<string, any[]>>((acc, c) => {
      const key = c.habitId || "none";
      if (!acc[key]) acc[key] = [];
      acc[key].push(c);
      return acc;
    }, {});

    const habitSummaries: HabitSummary[] = habits.map(h => {
      const habitCompletions = completionByHabit[h.id] || [];
      const lastTick = h.lastTick ?? null;

      const last7 = habitCompletions.filter(
        (c: any) => c.date >= sevenDaysAgo && c.date <= now
      );
      const last30 = habitCompletions.filter(
        (c: any) => c.date >= thirtyDaysAgo && c.date <= now
      );

      const completed7 = last7.filter(c => c.done).length;
      const total7 = last7.length || 0;
      const completed30 = last30.filter(c => c.done).length;
      const total30 = last30.length || 0;

      const completionRate7d = total7 > 0 ? Math.round((completed7 / total7) * 100) : 0;
      const completionRate30d = total30 > 0 ? Math.round((completed30 / total30) * 100) : 0;

      const schedule = (h.schedule as any) || {};
      const scheduledTime = typeof schedule.time === "string" ? schedule.time : null;

      return {
        id: h.id,
        title: h.title,
        streak: h.streak ?? 0,
        lastTick,
        completionRate7d,
        completionRate30d,
        scheduledTime,
        importance: h.importance ?? 3,
      };
    });

    const totalHabits = habitSummaries.length;
    const activeHabits = habitSummaries.filter(h => h.streak > 0).length;
    const dormantHabits = habitSummaries.filter(h => h.streak === 0 && h.lastTick !== null).length;
    const neverStartedHabits = habitSummaries.filter(h => h.lastTick === null).length;

    const longestCurrentStreak = habitSummaries.reduce(
      (max, h) => (h.streak > max ? h.streak : max),
      0
    );
    const longestStreakHabit = habitSummaries.find(h => h.streak === longestCurrentStreak)?.title ?? null;

    // Overall rates
    const last7 = completions.filter((c: any) => c.date >= sevenDaysAgo && c.date <= now);
    const last30 = completions.filter((c: any) => c.date >= thirtyDaysAgo && c.date <= now);

    const completed7 = last7.filter(c => c.done).length;
    const completed30 = last30.filter(c => c.done).length;

    const last7DaysRate =
      last7.length > 0 ? Math.round((completed7 / last7.length) * 100) : 0;
    const last30DaysRate =
      last30.length > 0 ? Math.round((completed30 / last30.length) * 100) : 0;

    // Days since last action
    const lastEvent = events[events.length - 1] ?? null;
    let daysSinceLastAction = 999;
    if (lastEvent) {
      daysSinceLastAction = Math.max(
        0,
        Math.floor((now.getTime() - new Date(lastEvent.ts).getTime()) / 86400000)
      );
    }

    // Basic active / least-active hours from completions
    const hourCounts: Record<number, { done: number; total: number }> = {};
    completions.forEach((c: any) => {
      const hour = new Date(c.date).getHours();
      if (!hourCounts[hour]) hourCounts[hour] = { done: 0, total: 0 };
      hourCounts[hour].total += 1;
      if (c.done) hourCounts[hour].done += 1;
    });

    const mostActiveHours: number[] = [];
    const leastActiveHours: number[] = [];

    const entries = Object.entries(hourCounts);
    if (entries.length > 0) {
      entries.sort(([, a], [, b]) => b.done - a.done);
      mostActiveHours.push(
        ...entries
          .slice(0, 3)
          .map(([hour]) => parseInt(hour, 10))
          .filter(h => !Number.isNaN(h))
      );

      entries.sort(([, a], [, b]) => a.done - b.done);
      leastActiveHours.push(
        ...entries
          .slice(0, 3)
          .map(([hour]) => parseInt(hour, 10))
          .filter(h => !Number.isNaN(h))
      );
    }

    return {
      habits: habitSummaries,
      totalHabits,
      activeHabits,
      dormantHabits,
      neverStartedHabits,
      longestCurrentStreak,
      longestStreakHabit,
      last7DaysRate,
      last30DaysRate,
      daysSinceLastAction,
      mostActiveHours,
      leastActiveHours,
    };
  }

  private buildUserPatterns(behavior: UserBehavior, completions: any[]): UserPatterns {
    const driftWindows: DriftWindow[] = [];
    const dayOfWeekPatterns: DayOfWeekPattern[] = [];

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 86400000);

    const completions30 = completions.filter((c: any) => c.date >= thirtyDaysAgo);

    // Day-of-week patterns
    for (let day = 0; day < 7; day++) {
      const dayComps = completions30.filter(
        (c: any) => new Date(c.date).getDay() === day
      );
      const done = dayComps.filter(c => c.done).length;
      const total = dayComps.length;
      const completionRate = total > 0 ? Math.round((done / total) * 100) : 0;

      const pattern: DayOfWeekPattern = {
        day,
        dayName: dayNameFromIndex(day),
        completionRate,
        avgCompletions: total / Math.max(1, 4), // rough average
        isStrongDay: completionRate >= 70 && total >= 5,
        isWeakDay: completionRate > 0 && completionRate <= 40 && total >= 5,
      };

      dayOfWeekPatterns.push(pattern);
    }

    const strongestDay =
      dayOfWeekPatterns.reduce(
        (best, d) => (d.completionRate > (best?.completionRate ?? -1) ? d : best),
        null as DayOfWeekPattern | null
      ) ?? null;

    const weakestDay =
      dayOfWeekPatterns.reduce(
        (worst, d) =>
          d.completionRate > 0 && d.completionRate < (worst?.completionRate ?? 101)
            ? d
            : worst,
        null as DayOfWeekPattern | null
      ) ?? null;

    // Drift windows (very simple heuristic)
    const hourStats: Record<number, { done: number; total: number }> = {};
    completions30.forEach((c: any) => {
      const hour = new Date(c.date).getHours();
      if (!hourStats[hour]) hourStats[hour] = { done: 0, total: 0 };
      hourStats[hour].total += 1;
      if (c.done) hourStats[hour].done += 1;
    });

    for (const [hourStr, stats] of Object.entries(hourStats)) {
      if (stats.total < 5) continue;
      const rate = Math.round((stats.done / stats.total) * 100);
      if (rate <= 50) {
        driftWindows.push({
          hourOfDay: parseInt(hourStr, 10),
          dayOfWeek: null,
          completionRate: rate,
          sampleSize: stats.total,
          description: `Low-completion window at ${hourStr}:00`,
        });
      }
    }

    // Avoided habits: any habit with very low long-term completion
    const avoidedHabits = behavior.habits
      .filter(h => h.completionRate30d <= 20 && h.lastTick !== null)
      .map(h => h.id);

    // Consistency score = blend of rates + streaks
    const consistencyScoreRaw =
      behavior.last30DaysRate * 0.6 +
      behavior.last7DaysRate * 0.3 +
      (behavior.longestCurrentStreak > 0 ? 10 : 0);
    const consistencyScore = clamp(Math.round(consistencyScoreRaw), 0, 100);

    const engagementPattern: EngagementPattern = this.inferEngagementPattern(
      behavior,
      dayOfWeekPatterns
    );

    return {
      driftWindows,
      dayOfWeekPatterns,
      strongestDay,
      weakestDay,
      engagementPattern,
      avoidedHabits,
      consistencyScore,
    };
  }

  private inferEngagementPattern(
    behavior: UserBehavior,
    dayPatterns: DayOfWeekPattern[]
  ): EngagementPattern {
    if (behavior.daysSinceLastAction >= 3) return "ghost";
    if (behavior.totalHabits === 0) return "new_user";

    const avgRate = behavior.last30DaysRate;
    const weekday = dayPatterns.filter(d => d.day >= 1 && d.day <= 5);
    const weekend = dayPatterns.filter(d => d.day === 0 || d.day === 6);

    const weekdayAvg =
      weekday.reduce((sum, d) => sum + d.completionRate, 0) /
      Math.max(1, weekday.length);
    const weekendAvg =
      weekend.reduce((sum, d) => sum + d.completionRate, 0) /
      Math.max(1, weekend.length);

    if (avgRate >= 60 && behavior.daysSinceLastAction <= 1) return "daily_engaged";
    if (weekendAvg >= weekdayAvg + 15) return "weekend_warrior";
    if (weekdayAvg >= weekendAvg + 15) return "weekday_warrior";
    if (avgRate <= 20) return "sporadic";
    if (behavior.last7DaysRate < behavior.last30DaysRate - 15) return "fading";
    return "sporadic";
  }

  private buildContradictions(
    identity: UserIdentity,
    behavior: UserBehavior,
    patterns: UserPatterns,
    factsJson: any
  ): ContradictionLayer {
    const stored: Contradiction[] = Array.isArray(factsJson.contradictions)
      ? factsJson.contradictions
      : [];

    const active = stored.filter(c => c.status === "active");
    const resolved = stored.filter(c => c.status === "resolved");

    const primaryContradiction =
      active.sort((a, b) => b.severity - a.severity)[0] ?? null;

    return {
      active,
      resolved,
      primaryContradiction,
    };
  }

  private buildPsychology(
    storedLearned: LearnedUserModel | null,
    factsJson: any
  ): UserPsychology {
    const defaultShame: ShameSensitivity = {
      score: 0.5,
      ghostsAfterMissedStreak: false,
      ghostsAfterConfrontation: false,
      deletesHabitsAfterFailure: false,
      respondsToSoftReentry: false,
      ignoresAfterMultipleNudges: false,
      maxMessageIntensity: 6,
      requiresSoftLanding: false,
      confidence: 0,
      dataPoints: 0,
    };

    const shame = storedLearned?.shameSensitivity ?? defaultShame;
    const excuses = storedLearned?.excuses ?? [];
    const narratives = storedLearned?.narratives ?? [];
    const timeWasters: string[] = Array.isArray(factsJson.timeWasters)
      ? factsJson.timeWasters
      : [];

    const motivationStyle: MotivationStyle =
      factsJson.motivationStyle ?? "unknown";

    return {
      shameSensitivity: shame,
      recurringExcuses: excuses,
      timeWasters,
      limitingNarratives: narratives,
      motivationStyle,
    };
  }

  private buildPredictions(
    behavior: UserBehavior,
    psychology: UserPsychology
  ): UserPredictions {
    // Simple safe heuristic: slip risk based on rate + days since last action
    let p = 0.2;

    if (behavior.last7DaysRate < 40) p += 0.3;
    if (behavior.last30DaysRate < 40) p += 0.2;
    if (behavior.daysSinceLastAction >= 2) p += 0.3;
    if (psychology.recurringExcuses.length >= 3) p += 0.1;

    p = clamp(p, 0, 1);

    const slipRisk: SlipRiskAssessment = {
      probability: p,
      level: riskLevelFromProbability(p),
      factors: [
        {
          key: "recentCompletion",
          description: `7-day completion rate at ${behavior.last7DaysRate}%`,
          weight: 0.4,
          direction: behavior.last7DaysRate < 40 ? "up" : "down",
        },
        {
          key: "daysSinceLastAction",
          description: `${behavior.daysSinceLastAction} days since last action`,
          weight: 0.3,
          direction: behavior.daysSinceLastAction >= 2 ? "up" : "down",
        },
      ],
      primaryFactors: ["recentCompletion", "daysSinceLastAction"],
      estimatedTimeToSlip:
        behavior.daysSinceLastAction >= 2 ? 0 : 24, // very rough
      trend: "stable",
    };

    // Engagement risk = similar but a bit softer
    let pEng = 0.1;
    if (behavior.last30DaysRate < 50) pEng += 0.2;
    if (behavior.daysSinceLastAction >= 3) pEng += 0.3;
    const engagementRisk: SlipRiskAssessment = {
      probability: clamp(pEng, 0, 1),
      level: riskLevelFromProbability(pEng),
      factors: [],
      primaryFactors: [],
      estimatedTimeToSlip: null,
      trend: "stable",
    };

    // Streak risks: any streak > 5 days but low recent completion
    const streakRisks: StreakRisk[] = behavior.habits
      .filter(h => h.streak >= 5)
      .map(h => {
        let risk: StreakRisk["riskLevel"] = "low";
        let reason = "Healthy streak";

        if (h.completionRate7d < 70) {
          risk = "medium";
          reason = "7-day completion is soft for this streak";
        }
        if (h.completionRate7d < 50) {
          risk = "high";
          reason = "Very low recent completion threatens this streak";
        }

        return {
          habitId: h.id,
          habitTitle: h.title,
          streak: h.streak,
          riskLevel: risk,
          reason,
        };
      });

    return {
      slipRisk,
      engagementRisk,
      streakRisks,
    };
  }

  private buildUserArc(identity: UserIdentity, learned: LearnedUserModel | null): UserArc {
    const days = identity.daysInSystem;
    let phase: UserArc["phase"] = "observer";
    if (days >= 14 && days < 60) phase = "architect";
    if (days >= 60) phase = "oracle";

    const phaseStartDay = phase === "observer" ? 0 : phase === "architect" ? 14 : 60;
    const daysInPhase = Math.max(0, days - phaseStartDay);

    const milestones = learned?.milestones ?? [];

    // Very simple next-milestone text
    let nextMilestone: string | null = null;
    if (phase === "observer") {
      nextMilestone = "Complete 14 days with at least 50% completion";
    } else if (phase === "architect") {
      nextMilestone = "Hold 70%+ completion for 30 days";
    } else {
      nextMilestone = "Sustain your system while evolving your identity";
    }

    return {
      phase,
      daysInPhase,
      milestones,
      nextMilestone,
    };
  }

  private normalizeLearnedModel(stored: LearnedUserModel | null): LearnedUserModel | null {
    if (!stored) return null;
    return {
      fingerprint: stored.fingerprint ?? null,
      shameSensitivity: stored.shameSensitivity ?? null,
      triggerChains: stored.triggerChains ?? [],
      messagePatterns: stored.messagePatterns ?? [],
      commitments: stored.commitments ?? [],
      excuses: stored.excuses ?? [],
      narratives: stored.narratives ?? [],
      dataPointsUsed: stored.dataPointsUsed ?? 0,
      confidenceLevel: stored.confidenceLevel ?? "insufficient",
      milestones: stored.milestones ?? [],
    };
  }

  private emptyLearnedModel(): LearnedUserModel {
    return {
      fingerprint: null,
      shameSensitivity: null,
      triggerChains: [],
      messagePatterns: [],
      commitments: [],
      excuses: [],
      narratives: [],
      dataPointsUsed: 0,
      confidenceLevel: "insufficient",
      milestones: [],
    };
  }

  private async persistLearnedModel(userId: string, learned: LearnedUserModel): Promise<void> {
    // Upsert into UserFacts.json.learnedModel
    const existing = await prisma.userFacts.findUnique({ where: { userId } });
    const currentJson = (existing?.json as any) || {};
    const newJson = {
      ...currentJson,
      learnedModel: learned,
    };

    if (existing) {
      await prisma.userFacts.update({
        where: { userId },
        data: { json: newJson },
      });
    } else {
      await prisma.userFacts.create({
        data: {
          userId,
          json: newJson,
        },
      });
    }

    // Invalidate caches
    await redis.del(`deep_model:${userId}`);
    await redis.del(`learned_model:${userId}`);
    await redis.set(
      `learned_model:${userId}`,
      JSON.stringify(learned),
      "EX",
      LEARNED_MODEL_CACHE_TTL_SECONDS
    );
  }
}

// =============================================================================
// EXPORT SINGLETON
// =============================================================================

export const deepUserModel = new DeepUserModelService();