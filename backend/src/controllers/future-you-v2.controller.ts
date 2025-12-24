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
    console.log(`\n🔥 ═══════════════════════════════════════`);
    console.log(`🔥 V2 FUTURE-YOU CHAT ENDPOINT HIT`);
    console.log(`🔥 Time: ${new Date().toISOString()}`);
    console.log(`🔥 ═══════════════════════════════════════\n`);
    
    try {
      const userId = getUserIdOr401(req);
      console.log(`👤 User ID: ${userId.substring(0, 12)}...`);
      
      const { message } = req.body || {};
      console.log(`💬 Message: "${message?.substring(0, 100)}..."`);
      
      // 🔒 PAYWALL: Check premium status
      // TEMP: Disabled for testing - re-enable before production launch
      // const isPremium = await premiumService.isPremium(userId);
      // if (!isPremium) {
      //   return reply.code(402).send({ 
      //     error: "Premium subscription required",
      //     code: "PREMIUM_REQUIRED"
      //   });
      // }
      
      if (!message || typeof message !== "string") {
        console.error(`❌ No message provided in request body`);
        return reply.code(400).send({ error: "Message required" });
      }
      
      console.log(`🧠 Calling futureYouV2Service.chat...`);
      const aiResponse = await futureYouV2Service.chat(userId, message);
      
      console.log(`✅ V2 chat response generated successfully`);
      console.log(`📝 Response preview: "${aiResponse?.substring(0, 100)}..."`);
      console.log(`🔥 ═══════════════════════════════════════\n`);
      
      return { message: aiResponse };
    } catch (err: any) {
      console.error(`\n❌ ═══════════════════════════════════════`);
      console.error(`❌ V2 FUTURE-YOU CHAT ERROR`);
      console.error(`❌ Error: ${err.message}`);
      console.error(`❌ Stack: ${err.stack}`);
      console.error(`❌ ═══════════════════════════════════════\n`);
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

