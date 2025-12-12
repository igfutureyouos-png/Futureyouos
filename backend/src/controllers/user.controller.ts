import { FastifyInstance } from 'fastify';
import { prisma } from '../utils/db';
import { memoryService } from '../services/memory.service';

function getUserIdOr401(req: any) {
  const uid = req?.user?.id || req.headers["x-user-id"];
  if (!uid) throw Object.assign(new Error("Unauthorized"), { statusCode: 401 });
  return uid;
}

export async function userController(fastify: FastifyInstance) {
  /**
   * 🆕 Create or get user (auto-creation for mobile app)
   */
  fastify.post('/api/v1/users', async (req: any, reply) => {
    try {
      const userId = req.headers['x-user-id'] as string;
      
      if (!userId) {
        return reply.code(400).send({ error: 'x-user-id header required' });
      }

      // Check if user exists
      let user = await prisma.user.findUnique({ 
        where: { id: userId } 
      });

      if (user) {
        return { user, created: false };
      }

      // Create new user with defaults
      user = await prisma.user.create({
        data: {
          id: userId,
          email: `${userId}@futureyou.app`,
          tz: 'Europe/London',
          tone: 'balanced',
          intensity: 2,
          mentorId: 'marcus',
          nudgesEnabled: true,
          briefsEnabled: true,
          debriefsEnabled: true,
        },
      });

      // 🧠 Initialize UserFacts for AI OS brain
      // This is CRITICAL - without this, the deep user model has no foundation
      try {
        await prisma.userFacts.create({
          data: {
            userId,
            json: {
              learnedModel: {
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
              },
              behaviorPatterns: {
                drift_windows: [],
                consistency_score: 0,
                avoidance_triggers: [],
                return_protocols: [],
              },
              reflectionHistory: {
                themes: [],
                emotional_arc: "flat",
                depth_score: 0,
              },
              os_phase: {
                current_phase: "observer",
                started_at: new Date().toISOString(),
                days_in_phase: 0,
                phase_transitions: [],
              },
            },
          },
        });
        console.log(`🧠 UserFacts initialized for ${userId}`);
      } catch (factsErr) {
        // Don't fail user creation if UserFacts fails - it can be created later
        console.warn(`⚠️ Failed to initialize UserFacts for ${userId}:`, factsErr);
      }

      console.log(`✅ Created new user: ${userId}`);
      return { user, created: true };
    } catch (err: any) {
      const code = err.statusCode || 500;
      console.error(`❌ User creation error:`, err);
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 👤 Get user profile
   */
  fastify.get('/api/v1/users/:userId', async (req: any, reply) => {
    try {
      const { userId } = req.params;
      
      const user = await prisma.user.findUnique({ 
        where: { id: userId } 
      });

      if (!user) {
        return reply.code(404).send({ error: 'User not found' });
      }

      return { user };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 📝 Update user profile
   */
  fastify.put('/api/v1/users/:userId', async (req: any, reply) => {
    try {
      const { userId } = req.params;
      const updates = req.body as Partial<{
        email: string;
        tz: string;
        tone: 'strict' | 'balanced' | 'light';
        intensity: number;
        mentorId: string;
        nudgesEnabled: boolean;
        briefsEnabled: boolean;
        debriefsEnabled: boolean;
      }>;

      const user = await prisma.user.update({
        where: { id: userId },
        data: updates,
      });

      return { user };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 🆔 Store user identity (name, age, burning question)
   * Also initializes 7-day welcome series for new users
   */
  fastify.post("/api/v1/user/identity", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const { name, age, burningQuestion } = req.body;
      
      // Save to UserFacts.json.identity for consciousness system
      await memoryService.upsertFacts(userId, {
        identity: {
          name,
          age,
          burningQuestion,
        },
      });
      
      console.log(`✅ Identity saved for ${userId}: name="${name}", age=${age}`);
      
      // 🎉 Initialize 7-day welcome series for new users
      const { welcomeSeriesService } = await import('../services/welcome-series.service');
      await welcomeSeriesService.initializeForUser(userId);
      
      return { success: true };
    } catch (err: any) {
      console.error(`❌ Failed to save identity:`, err);
      return reply.code(err.statusCode || 500).send({ error: err.message });
    }
  });
}

