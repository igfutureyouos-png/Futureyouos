import { FastifyInstance } from "fastify";
import { futureYouV2Service } from "../services/future-you-v2.service";
import { premiumService } from "../services/premium.service";

function getUserIdOr401(req: any) {
  const uid = req?.user?.id || req.headers["x-user-id"];
  if (!uid) throw Object.assign(new Error("Unauthorized"), { statusCode: 401 });
  return uid;
}

export async function futureYouChatControllerV2(fastify: FastifyInstance) {
  // Main chat endpoint
  fastify.post("/api/v2/future-you/freeform", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const { message } = req.body || {};
      
      // 🔒 PAYWALL: Check premium status
      const isPremium = await premiumService.isPremium(userId);
      if (!isPremium) {
        return reply.code(402).send({ 
          error: "Premium subscription required",
          code: "PREMIUM_REQUIRED"
        });
      }
      
      if (!message || typeof message !== "string") {
        return reply.code(400).send({ error: "Message required" });
      }
      
      const aiResponse = await futureYouV2Service.chat(userId, message);
      
      return { message: aiResponse };
    } catch (err: any) {
      console.error("Future‑You v2 error:", err);
      return reply.code(err.statusCode || 500).send({ error: err.message });
    }
  });

  // Clear chat history
  fastify.post("/api/v2/future-you/clear-history", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      return await futureYouV2Service.clearHistory(userId);
    } catch (err: any) {
      console.error("Future‑You v2 clear error:", err);
      return reply.code(err.statusCode || 500).send({ error: err.message });
    }
  });
}

