import { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import { prisma } from "../utils/db";

/**
 * 🎯 METRICS CONTROLLER
 * Returns real-time OS metrics for the AI consciousness system
 */

interface MetricsResponse {
  discipline: number;
  disciplineBreakdown: {
    today: number;
    weekly: number;
  };
  systemStrength: number;
  currentStreak: number;
  longestStreak: number;
  activeHabits: number;
  completionRateLast7Days: number;
}

export async function metricsController(fastify: FastifyInstance) {
  /**
   * GET /api/v1/user/metrics
   * Returns comprehensive OS metrics for the user
   */
  fastify.get("/metrics", async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = req.headers["x-user-id"] as string;

    if (!userId) {
      return reply.status(401).send({ error: "User ID required" });
    }

    try {
      const metrics = await calculateUserMetrics(userId);
      return reply.send(metrics);
    } catch (err: any) {
      console.error("Failed to calculate metrics:", err);
      return reply.status(500).send({ error: err.message });
    }
  });
}

/**
 * 📊 CALCULATE USER METRICS
 * Core metric calculation logic - matches frontend calculations
 */
async function calculateUserMetrics(userId: string): Promise<MetricsResponse> {
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  // Get all user habits
  const habits = await prisma.habit.findMany({
    where: { userId },
    select: {
      id: true,
      title: true,
      streak: true,
      schedule: true,
      lastTick: true,
    },
  });

  if (habits.length === 0) {
    return {
      discipline: 0,
      disciplineBreakdown: { today: 0, weekly: 0 },
      systemStrength: 0,
      currentStreak: 0,
      longestStreak: 0,
      activeHabits: 0,
      completionRateLast7Days: 0,
    };
  }

  // Get habit completion events for last 7 days
  const events = await prisma.event.findMany({
    where: {
      userId,
      type: "habit_tick",
      ts: { gte: sevenDaysAgo },
    },
    orderBy: { ts: "desc" },
  });

  // 1. CALCULATE TODAY'S COMPLETION RATE
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);

  const todayHabits = habits.filter((h) => isScheduledForToday(h, now));
  const todayCompletions = events.filter(
    (e) => e.ts >= todayStart && e.ts < todayEnd
  );

  const todayCompletion =
    todayHabits.length > 0
      ? (todayCompletions.length / todayHabits.length) * 100
      : 0;

  // 2. CALCULATE WEEKLY COMPLETION RATE
  const weeklyCompletions = calculateWeeklyCompletion(habits, events, now);

  // 3. DISCIPLINE (Weighted: 60% today + 40% weekly)
  const discipline = todayCompletion * 0.6 + weeklyCompletions * 0.4;

  // 4. CALCULATE STREAKS
  const { currentStreak, longestStreak } = calculateStreaks(habits, events);

  // 5. SYSTEM STRENGTH (40% streak + 35% completion + 25% consistency)
  const streakScore = Math.min((currentStreak / 20) * 100, 100); // Capped at 20 days
  const completionScore = weeklyCompletions;
  const consistencyScore = calculateConsistencyScore(habits, events, now);

  const systemStrength =
    streakScore * 0.4 + completionScore * 0.35 + consistencyScore * 0.25;

  // 6. ACTIVE HABITS (scheduled for today)
  const activeHabits = todayHabits.length;

  return {
    discipline: Math.round(discipline),
    disciplineBreakdown: {
      today: Math.round(todayCompletion),
      weekly: Math.round(weeklyCompletions),
    },
    systemStrength: Math.round(systemStrength),
    currentStreak,
    longestStreak,
    activeHabits,
    completionRateLast7Days: Math.round(weeklyCompletions),
  };
}

/**
 * 📅 CHECK IF HABIT IS SCHEDULED FOR TODAY
 */
function isScheduledForToday(habit: any, date: Date): boolean {
  // For simplicity, assume all habits are daily
  // In production, parse habit.schedule JSON and check repeat days
  return true;
}

/**
 * 📊 CALCULATE WEEKLY COMPLETION RATE
 */
function calculateWeeklyCompletion(
  habits: any[],
  events: any[],
  now: Date
): number {
  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    return d;
  });

  let totalScheduled = 0;
  let totalCompleted = 0;

  for (const day of last7Days) {
    const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

    const scheduledHabits = habits.filter((h) => isScheduledForToday(h, day));
    const completedHabits = events.filter(
      (e) => e.ts >= dayStart && e.ts < dayEnd
    );

    totalScheduled += scheduledHabits.length;
    totalCompleted += completedHabits.length;
  }

  return totalScheduled > 0 ? (totalCompleted / totalScheduled) * 100 : 0;
}

/**
 * 🔥 CALCULATE CURRENT AND LONGEST STREAKS
 */
function calculateStreaks(
  habits: any[],
  events: any[]
): { currentStreak: number; longestStreak: number } {
  // Simplified streak calculation
  // Count consecutive days with at least one habit completion
  const now = new Date();
  let currentStreak = 0;
  let longestStreak = 0;
  let currentCount = 0;

  for (let i = 0; i < 365; i++) {
    const checkDate = new Date(now);
    checkDate.setDate(checkDate.getDate() - i);
    checkDate.setHours(0, 0, 0, 0);

    const dayStart = checkDate;
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

    const hasCompletions = events.some((e) => e.ts >= dayStart && e.ts < dayEnd);

    if (hasCompletions) {
      currentCount++;
      if (i === 0 || currentStreak > 0) {
        currentStreak++;
      }
      longestStreak = Math.max(longestStreak, currentCount);
    } else {
      if (i === 0) {
        currentStreak = 0;
      }
      currentCount = 0;
    }
  }

  return { currentStreak, longestStreak };
}

/**
 * 📈 CALCULATE CONSISTENCY SCORE
 * Lower variance in daily completion = higher consistency
 */
function calculateConsistencyScore(
  habits: any[],
  events: any[],
  now: Date
): number {
  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    return d;
  });

  const completionRates = last7Days.map((day) => {
    const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

    const scheduledHabits = habits.filter((h) => isScheduledForToday(h, day));
    const completedHabits = events.filter(
      (e) => e.ts >= dayStart && e.ts < dayEnd
    );

    return scheduledHabits.length > 0
      ? (completedHabits.length / scheduledHabits.length) * 100
      : 0;
  });

  // Calculate variance
  const mean =
    completionRates.reduce((a, b) => a + b, 0) / completionRates.length;
  const variance =
    completionRates
      .map((rate) => Math.pow(rate - mean, 2))
      .reduce((a, b) => a + b, 0) / completionRates.length;
  const stdDev = Math.sqrt(variance);

  // Lower standard deviation = higher consistency
  // Perfect consistency (0 variance) = 100, high variance (>30) = 0
  const consistencyScore = Math.max(0, Math.min(100, 100 - (stdDev / 30) * 100));

  return consistencyScore;
}

