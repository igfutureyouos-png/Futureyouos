// src/modules/coach/coach.service.ts
import { prisma } from "../../utils/db";
import { aiService } from "../../services/ai.service";
import { notificationsService } from "../../services/notifications.service";

export class CoachService {
  /**
   * 🔁 Sync habit + completion data (observer mode)
   * Logs habit completions as events for the AI brain to interpret.
   * 
   * CRITICAL: Events must include full streak data for the AI OS brain:
   * - habitId, habitTitle, completed, streak, previousStreak, completedAt
   */
  async sync(
    userId: string,
    habits: any[],
    completions: { habitId: string; date: string; done: boolean }[]
  ) {
    if (!userId) throw new Error("Missing userId");

    if (Array.isArray(completions) && completions.length > 0) {
      // Query all habits to get titles and current streaks
      const userHabits = await prisma.habit.findMany({
        where: { userId },
        select: { id: true, title: true, streak: true },
      });
      
      // Build a lookup map for quick access
      const habitMap = new Map(userHabits.map(h => [h.id, h]));
      
      const writes = completions.map((c) => {
        const habit = habitMap.get(c.habitId);
        const currentStreak = habit?.streak ?? 0;
        
        // Calculate what the streak will be after this action
        // If completing: streak goes up by 1
        // If uncompleting: streak resets to 0 (previousStreak preserves old value)
        const newStreak = c.done ? currentStreak + 1 : 0;
        
        return prisma.event.create({
          data: {
            userId,
            type: "habit_action",
            payload: {
              habitId: c.habitId,
              habitTitle: habit?.title || "Unknown Habit",
              completed: c.done,
              streak: newStreak,
              previousStreak: currentStreak,
              completedAt: new Date().toISOString(),
              scheduledTime: null, // Could be enhanced later if schedule data is passed
            },
          },
        });
      });
      await Promise.allSettled(writes);
    }

    return { ok: true, logged: completions?.length ?? 0 };
  }

  /**
   * 🧠 Retrieve the most recent coach messages (briefs, letters, nudges, etc.)
   */
  async getMessages(userId: string) {
    if (!userId) throw new Error("Missing userId");

    const events = await prisma.event.findMany({
      where: {
        userId,
        type: { in: ["morning_brief", "evening_debrief", "nudge", "coach", "mirror"] },
      },
      orderBy: { ts: "desc" },
      take: 30,
    });

    return events.map((e) => ({
      id: e.id,
      userId,
      kind: this.mapEventTypeToKind(e.type),
      title: this.titleForKind(e.type),
      body: (e.payload as any)?.text ?? "",
      meta: e.payload,
      createdAt: e.ts,
      readAt: null,
    }));
  }

  /**
   * 💌 Generate a reflective "Letter from Future You"
   */
  async generateLetter(userId: string, topic: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error("User not found");

    const mentor = (user as any)?.mentorId || "marcus";
    const prompt = `Write a reflective, concise letter from Future You about "${topic}". Encourage growth and self-alignment.`;

    const text = await aiService.generateMentorReply(userId, mentor, prompt, {
      purpose: "letter",
      maxChars: 800,
    });

    const event = await prisma.event.create({
      data: {
        userId,
        type: "coach", // ✅ valid Prisma enum
        payload: { text, topic },
      },
    });

    await notificationsService.send(
      userId,
      "Letter from Future You",
      this.truncate(text, 180)
    );

    return { ok: true, message: text, id: event.id };
  }

  /**
   * 📊 Optional — analyzes user’s habit patterns
   */
  async analyzePatterns(userId: string) {
    const recent = await prisma.event.findMany({
      where: { userId },
      orderBy: { ts: "desc" },
      take: 200,
    });

    const keeps = recent.filter(
      (e) => e.type === "habit_action" && (e.payload as any)?.completed === true
    ).length;
    const misses = recent.filter(
      (e) => e.type === "habit_action" && (e.payload as any)?.completed === false
    ).length;
    const ratio = keeps + misses > 0 ? keeps / (keeps + misses) : 0;

    return {
      fulfillmentRate: ratio,
      keeps,
      misses,
      total: keeps + misses,
      lastActivity: recent[0]?.ts ?? null,
    };
  }

  private mapEventTypeToKind(type: string): string {
    switch (type) {
      case "morning_brief": return "brief";
      case "evening_debrief": return "debrief";  // ✅ FIXED: was "brief"
      case "nudge": return "nudge";
      case "coach": return "letter";
      case "mirror": return "mirror";
      default: return "nudge";
    }
  }

  private titleForKind(type: string): string {
    switch (type) {
      case "morning_brief": return "Morning Brief";
      case "evening_debrief": return "Evening Debrief";
      case "nudge": return "Nudge";
      case "coach": return "Letter from Future You";
      case "mirror": return "Mirror Reflection";
      default: return "Message";
    }
  }

  private truncate(s: string, n: number) {
    return s.length > n ? s.slice(0, n - 1) + "…" : s;
  }
}

export const coachService = new CoachService();
