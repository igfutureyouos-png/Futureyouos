// src/modules/coach/coach.controller.ts
import { FastifyInstance } from "fastify";
import { prisma } from "../../utils/db";
import { aiService } from "../../services/ai.service";
import { notificationsService } from "../../services/notifications.service";
import { CoachService } from "./coach.service";

const coachService = new CoachService();

function getUserIdOr401(req: any): string {
  const uid = req?.user?.id || req.headers["x-user-id"];
  if (!uid || typeof uid !== "string") {
    const err: any = new Error("Unauthorized: missing user id");
    err.statusCode = 401;
    throw err;
  }
  return uid;
}

export default async function coachController(fastify: FastifyInstance) {
  /**
   * 🔁 Observer sync: log completions to events
   * ✅ FIXED: Now calls coachService.sync() which auto-creates habits, updates streaks, writes to Completion table
   */
  fastify.post("/api/v1/coach/sync", async (req: any, reply) => {
    console.log('═══════════════════════════════════════════════════════════');
    console.log('🔥🔥🔥 SYNC ENDPOINT HIT 🔥🔥🔥');
    console.log('═══════════════════════════════════════════════════════════');
    
    try {
      const userId = getUserIdOr401(req);
      console.log(`👤 User ID: ${userId}`);
      
      const { habits = [], completions = [] } = req.body as {
        habits?: any[];
        completions?: { 
          habitId: string; 
          habitTitle?: string; 
          date: string; 
          done: boolean; 
          streak?: number;
        }[];
      };

      console.log(`📊 Received: ${habits.length} habits, ${completions.length} completions`);
      console.log(`📋 Completions data:`, JSON.stringify(completions, null, 2));

      // Use the service which handles auto-creation, streak updates, and Completion table writes
      const result = await coachService.sync(userId, habits, completions);

      console.log(`✅ [SYNC] Complete: ${result.logged} logged, ${result.streaks?.length || 0} habits synced`);
      console.log('═══════════════════════════════════════════════════════════');
      
      return result;
    } catch (err: any) {
      console.error(`❌ [SYNC] Error:`, err);
      console.error(`❌ Stack:`, err.stack);
      console.log('═══════════════════════════════════════════════════════════');
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 🧠 Fetch coach messages (nudges, briefs, letters)
   * ✅ FIXED: Now returns CoachMessage records instead of Event records
   * This eliminates duplicate nudges (previously created both CoachMessage + Event)
   */
  fastify.get("/api/v1/coach/messages", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      
      // Query CoachMessage table (new system) instead of Event table (old system)
      const coachMessages = await prisma.coachMessage.findMany({
        where: { userId },
        orderBy: { createdAt: "desc" },
        take: 30,
      });

      // Convert to API response format
      const messages = coachMessages.map((msg) => ({
        id: msg.id,
        userId: msg.userId,
        kind: msg.kind,
        title: msg.title,
        body: msg.body,
        meta: msg.meta || {},
        createdAt: msg.createdAt,
        readAt: msg.readAt,
      }));

      return { messages };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 💌 Generate one-off reflective letter (AI)
   */
  fastify.post("/api/v1/coach/reflect", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const { topic } = req.body as { topic: string };

      const user = await prisma.user.findUnique({ where: { id: userId } });
      const mentor = (user as any)?.mentorId || "marcus";

      const prompt = `Write a reflective short letter from Future You about: ${topic}`;
      const text = await aiService.generateMentorReply(userId, mentor, prompt, {
        purpose: "letter",
        maxChars: 800,
      });

      const event = await prisma.event.create({
        data: {
          userId,
          type: "coach", // ✅ matches Prisma enum
          payload: { text, topic },
        },
      });

      await notificationsService.send(
        userId,
        "Letter from Future You",
        text.slice(0, 180)
      );

      return { ok: true, message: text, id: event.id };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });
}

/** Helper mappers */
function mapEventTypeToKind(type: string): string {
  switch (type) {
    case "morning_brief": return "brief";
    case "evening_debrief": return "debrief";  // ✅ FIXED: was "brief"
    case "nudge": return "nudge";
    case "coach": return "letter";
    case "mirror": return "mirror";
    default: return "nudge";
  }
}

function titleForKind(type: string): string {
  switch (type) {
    case "morning_brief": return "Morning Brief";
    case "evening_debrief": return "Evening Debrief";
    case "nudge": return "Nudge";
    case "coach": return "Letter from Future You";
    case "mirror": return "Mirror Reflection";
    default: return "Message";
  }
}
