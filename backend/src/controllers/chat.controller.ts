import { FastifyInstance } from "fastify";
import { chatService } from "../services/chat.service";

function getUserIdOr401(req: any) {
  const uid = req?.user?.id || req.headers["x-user-id"];
  if (!uid) throw Object.assign(new Error("Unauthorized"), { statusCode: 401 });
  return uid;
}

export async function chatController(fastify: FastifyInstance) {
  // 💬 Main chat endpoint - now returns habit suggestions too
  fastify.post("/api/v1/chat", async (req: any, reply) => {
    console.log(`\n🔥 ═══════════════════════════════════════`);
    console.log(`🔥 OS CHAT ENDPOINT HIT`);
    console.log(`🔥 Time: ${new Date().toISOString()}`);
    console.log(`🔥 ═══════════════════════════════════════\n`);
    
    try {
      const userId = getUserIdOr401(req);
      console.log(`👤 User ID: ${userId.substring(0, 12)}...`);
      
      const { message } = req.body;
      console.log(`💬 Message: "${message?.substring(0, 100)}..."`);
      
      if (!message) {
        console.error(`❌ No message provided in request body`);
        return reply.code(400).send({ error: "Message required" });
      }
      
      console.log(`🧠 Calling chatService.nextMessage...`);
      const res = await chatService.nextMessage(userId, message);
      
      console.log(`✅ Chat response generated successfully`);
      console.log(`📝 Response preview: "${res.message?.substring(0, 100)}..."`);
      console.log(`🔥 ═══════════════════════════════════════\n`);
      
      return res;
    } catch (err: any) {
      console.error(`\n❌ ═══════════════════════════════════════`);
      console.error(`❌ OS CHAT ERROR`);
      console.error(`❌ Error: ${err.message}`);
      console.error(`❌ Stack: ${err.stack}`);
      console.error(`❌ ═══════════════════════════════════════\n`);
      return reply.code(err.statusCode || 500).send({ error: err.message });
    }
  });

  // 🎯 Accept AI habit suggestion and create it
  fastify.post("/api/v1/chat/accept-habit", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const { suggestion } = req.body;
      
      if (!suggestion || !suggestion.title || !suggestion.time) {
        return reply.code(400).send({ error: "Invalid suggestion" });
      }
      
      const habit = await chatService.createHabitFromSuggestion(userId, suggestion);
      return { success: true, habit };
    } catch (err: any) {
      return reply.code(err.statusCode || 500).send({ error: err.message });
    }
  });
}
