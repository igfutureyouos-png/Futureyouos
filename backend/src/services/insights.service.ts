// src/services/insights.service.ts
// 🔮 Proactive pattern analysis and recommendations
import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import OpenAI from "openai";
import { memoryService } from "./memory.service";

const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o";

function getOpenAIClient() {
  if (process.env.NODE_ENV === "build" || process.env.RAILWAY_ENVIRONMENT === "build") return null;
  if (!process.env.OPENAI_API_KEY) return null;
  const apiKey = process.env.OPENAI_API_KEY.trim();
  return new OpenAI({ apiKey });
}

export type Insight = {
  type: "pattern" | "recommendation" | "warning" | "celebration";
  title: string;
  body: string;
  priority: number; // 1-5
  actionable?: string; // Optional CTA
  meta?: any;
};

export class InsightsService {
  /**
   * 📊 Analyze user patterns and generate insights
   */
  async analyzePatterns(userId: string): Promise<Insight[]> {
    const cacheKey = `insights:${userId}:${new Date().toISOString().split("T")[0]}`;
    const cached = await redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const [habits, recentEvents, context] = await Promise.all([
      prisma.habit.findMany({ where: { userId } }),
      prisma.event.findMany({
        where: { userId, ts: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) } },
        orderBy: { ts: "desc" },
        take: 1000,
      }),
      memoryService.getUserContext(userId),
    ]);

    const insights: Insight[] = [];

    // 1️⃣ Identify weak days
    const dayOfWeekStats = this.analyzeDayOfWeek(recentEvents);
    const weakestDay = this.findWeakestDay(dayOfWeekStats);
    if (weakestDay) {
      insights.push({
        type: "pattern",
        title: `${weakestDay.day}s are your weak spot`,
        body: `You miss ${weakestDay.missRate.toFixed(0)}% of habits on ${weakestDay.day}s. Consider lighter commitments or better prep the day before.`,
        priority: 4,
        actionable: "Adjust your schedule",
        meta: { dayOfWeek: weakestDay.dayIndex, stats: dayOfWeekStats },
      });
    }

    // 2️⃣ Identify time-of-day patterns
    const timeStats = this.analyzeTimeOfDay(habits, recentEvents);
    if (timeStats.bestWindow) {
      insights.push({
        type: "recommendation",
        title: `You peak at ${timeStats.bestWindow}`,
        body: `${timeStats.successRate.toFixed(0)}% completion rate during this window. Stack important habits here.`,
        priority: 3,
        actionable: "Reschedule habits",
        meta: { timeWindow: timeStats.bestWindow },
      });
    }

    // 3️⃣ Streak monitoring
    const streakInsight = this.analyzeStreaks(habits);
    if (streakInsight) {
      insights.push(streakInsight);
    }

    // 4️⃣ Low-engagement habits (created but never done)
    const deadHabits = habits.filter((h) => h.streak === 0 && !h.lastTick);
    if (deadHabits.length > 0) {
      insights.push({
        type: "warning",
        title: `${deadHabits.length} habits never started`,
        body: `You created these but haven't touched them: ${deadHabits.map((h) => h.title).join(", ")}. Delete or commit.`,
        priority: 3,
        actionable: "Clean up habits",
        meta: { habits: deadHabits.map((h) => h.id) },
      });
    }

    // 5️⃣ AI-generated deep insight (weekly only)
    if (Math.random() < 0.3) {
      // 30% chance to avoid spam
      const aiInsight = await this.generateAIInsight(userId, habits, recentEvents, context);
      if (aiInsight) insights.push(aiInsight);
    }

    // Cache for 6 hours
    await redis.set(cacheKey, JSON.stringify(insights), "EX", 6 * 60 * 60);

    return insights;
  }

  /**
   * 📅 Weekly memory consolidation - summarize long-term patterns and generate weekly letter
   */
  async weeklyConsolidation(userId: string) {
    const insights = await this.analyzePatterns(userId);
    const openai = getOpenAIClient();
    if (!openai) return { ok: false };

    const context = await memoryService.getUserContext(userId);
    const summary = `
User has ${context.habitSummaries.length} active habits.
Recent insights:
${insights.map((i) => `- ${i.type}: ${i.title}`).join("\n")}

Recent events (last 100):
${context.recentEvents.slice(0, 100).map((e) => e.type).join(", ")}
`;

    // 1. Memory consolidation (update facts)
    const completion = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      temperature: 0.3,
      max_tokens: 300,
      messages: [
        {
          role: "system",
          content: "You are the memory engine for Future You OS. Consolidate patterns into persistent facts.",
        },
        {
          role: "user",
          content: `${summary}\n\nOutput JSON with 'factsPatch' (key-value updates to user memory) and 'weeklyReflection' (2-3 sentences).`,
        },
      ],
      response_format: { type: "json_object" as any },
    });

    let parsed: any = {};
    try {
      parsed = JSON.parse(completion.choices[0]?.message?.content || "{}");
    } catch {
      parsed = {};
    }

    if (parsed.factsPatch && Object.keys(parsed.factsPatch).length > 0) {
      await memoryService.upsertFacts(userId, parsed.factsPatch);
    }

    // 2. Generate and save weekly letter as CoachMessage (with activity gates)
    let weeklyLetterText = "";
    try {
      weeklyLetterText = await this.generateWeeklyLetterWithGates(userId);
      
      // Only save if we got actual content
      if (weeklyLetterText) {
        const { coachMessageService } = await import("./coach-message.service");
        await coachMessageService.createMessage(userId, "letter", weeklyLetterText, {
          source: "weekly_consolidation",
          insights: insights.map((i) => ({ type: i.type, title: i.title })),
        });
        
        console.log(`✅ Weekly letter generated and saved for user ${userId}`);
      }
    } catch (err) {
      console.error(`❌ Failed to generate weekly letter for ${userId}:`, err);
      // Continue even if letter generation fails
    }

    // 3. Save event for backward compatibility
    await prisma.event.create({
      data: {
        userId,
        type: "weekly_consolidation",
        payload: { 
          reflection: parsed.weeklyReflection, 
          insights, 
          factsPatch: parsed.factsPatch,
          letterGenerated: !!weeklyLetterText,
        },
      },
    });

    return { ok: true, reflection: parsed.weeklyReflection, insights, letterText: weeklyLetterText };
  }

  /**
   * 🚪 Generate weekly letter with activity gates
   * Gate 1: User must have been in system for at least 7 days
   * Gate 2: User must have at least 5 events in the past week
   */
  private async generateWeeklyLetterWithGates(userId: string): Promise<string> {
    // Gate 1: Days in system
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return "";
    
    const daysInSystem = Math.floor((Date.now() - user.createdAt.getTime()) / (1000 * 60 * 60 * 24));
    
    if (daysInSystem < 7) {
      console.log(`⏭️ User ${userId} only ${daysInSystem} days in system, skipping weekly letter`);
      return ""; // Skip letter for new users
    }
    
    // Gate 2: Minimum activity
    const recentEvents = await prisma.event.count({
      where: {
        userId,
        ts: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
      }
    });
    
    if (recentEvents < 5) {
      console.log(`⏭️ User ${userId} only ${recentEvents} events this week, sending onboarding reflection`);
      return this.getOnboardingReflection(user);
    }
    
    // Gates passed, generate real letter via CoachEngine
    console.log(`✅ User ${userId} passed activity gates (${daysInSystem} days, ${recentEvents} events), generating letter`);
    const { aiServiceV2 } = await import("./ai.service.v2");
    return aiServiceV2.generateWeeklyLetter(userId);
  }

  /**
   * 📝 Onboarding reflection for users who don't meet activity threshold
   */
  private getOnboardingReflection(user: any): string {
    const name = user.email?.split("@")[0] || "Friend";
    return `${name}, you're in your first week with Future-You OS. This isn't a time for deep letters yet — it's for building the habit foundation. Keep logging your days. The insights come from consistency, not perfection.`;
  }

  /**
   * 🔬 Analyze day-of-week patterns
   */
  private analyzeDayOfWeek(events: any[]) {
    const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    const stats: Record<number, { total: number; completed: number }> = {};

    for (let i = 0; i < 7; i++) stats[i] = { total: 0, completed: 0 };

    events
      .filter((e) => e.type === "habit_action")
      .forEach((e: any) => {
        const day = new Date(e.ts).getDay();
        stats[day].total++;
        if (e.payload?.completed) stats[day].completed++;
      });

    return days.map((name, i) => ({
      day: name,
      dayIndex: i,
      total: stats[i].total,
      completed: stats[i].completed,
      missRate: stats[i].total > 0 ? ((stats[i].total - stats[i].completed) / stats[i].total) * 100 : 0,
    }));
  }

  private findWeakestDay(stats: any[]) {
    const validDays = stats.filter((s) => s.total >= 3); // Require at least 3 data points
    if (validDays.length === 0) return null;
    validDays.sort((a, b) => b.missRate - a.missRate);
    return validDays[0].missRate > 30 ? validDays[0] : null; // Only flag if miss rate > 30%
  }

  /**
   * ⏰ Analyze time-of-day patterns
   */
  private analyzeTimeOfDay(habits: any[], events: any[]) {
    const windows = ["morning (6-12)", "afternoon (12-18)", "evening (18-23)"];
    const stats: Record<string, { total: number; completed: number }> = {
      morning: { total: 0, completed: 0 },
      afternoon: { total: 0, completed: 0 },
      evening: { total: 0, completed: 0 },
    };

    events
      .filter((e) => e.type === "habit_action")
      .forEach((e: any) => {
        const hour = new Date(e.ts).getHours();
        let window = "evening";
        if (hour >= 6 && hour < 12) window = "morning";
        else if (hour >= 12 && hour < 18) window = "afternoon";

        stats[window].total++;
        if (e.payload?.completed) stats[window].completed++;
      });

    const best = Object.entries(stats)
      .filter(([, s]) => s.total >= 5)
      .sort((a, b) => b[1].completed / Math.max(b[1].total, 1) - a[1].completed / Math.max(a[1].total, 1))[0];

    if (!best) return { bestWindow: null, successRate: 0 };

    const [window, data] = best;
    return {
      bestWindow: windows[["morning", "afternoon", "evening"].indexOf(window)],
      successRate: (data.completed / data.total) * 100,
    };
  }

  /**
   * 🔥 Analyze streaks
   */
  private analyzeStreaks(habits: any[]): Insight | null {
    const longStreaks = habits.filter((h) => h.streak >= 14);
    if (longStreaks.length > 0) {
      const best = longStreaks.sort((a, b) => b.streak - a.streak)[0];
      return {
        type: "celebration",
        title: `${best.streak}-day streak on ${best.title}! 🔥`,
        body: "This is the consistency that builds the future you. Keep the chain alive.",
        priority: 4,
        meta: { habitId: best.id, streak: best.streak },
      };
    }
    return null;
  }

  /**
   * 🧠 AI-generated deep insight (runs occasionally)
   */
  private async generateAIInsight(userId: string, habits: any[], events: any[], context: any): Promise<Insight | null> {
    const openai = getOpenAIClient();
    if (!openai) return null;

    try {
      const prompt = `
Analyze this user's habit patterns:
- ${habits.length} active habits
- Recent events: ${events.slice(0, 50).map((e) => e.type).join(", ")}
- Facts: ${JSON.stringify(context.facts || {})}

Generate ONE actionable insight (not obvious, deeply personalized).
Output JSON:
{
  "title": "Short headline",
  "body": "1-2 sentences with specific observation + action",
  "priority": 1-5
}
`;

      const completion = await openai.chat.completions.create({
        model: OPENAI_MODEL,
        temperature: 0.7,
        max_tokens: 150,
        messages: [
          { role: "system", content: "You are a pattern recognition engine for habit tracking." },
          { role: "user", content: prompt },
        ],
        response_format: { type: "json_object" as any },
      });

      const parsed = JSON.parse(completion.choices[0]?.message?.content || "{}");
      if (!parsed.title) return null;

      return {
        type: "pattern",
        title: parsed.title,
        body: parsed.body,
        priority: parsed.priority || 3,
        meta: { source: "ai_deep_insight" },
      };
    } catch (err) {
      console.warn("AI insight generation failed:", err);
      return null;
    }
  }
}

export const insightsService = new InsightsService();

