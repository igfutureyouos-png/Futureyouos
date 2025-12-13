// Test controller for manually triggering coach messages
import { FastifyInstance } from 'fastify';
import { prisma } from '../utils/db';
import { aiService } from '../services/ai.service';
import { notificationsService } from '../services/notifications.service';
import { schedulerQueue } from '../jobs/scheduler';
import { coachMessageService } from '../services/coach-message.service';

function getUserIdOr401(req: any): string {
  const uid = req?.user?.id || req.headers['x-user-id'];
  if (!uid || typeof uid !== 'string') {
    const err: any = new Error('Unauthorized: missing user id');
    err.statusCode = 401;
    throw err;
  }
  return uid;
}

export async function testController(fastify: FastifyInstance) {
  /**
   * 🔍 Check if schedulers are running
   */
  fastify.get('/api/v1/test/scheduler-status', async (req: any, reply) => {
    try {
      const repeatJobs = await schedulerQueue.getRepeatableJobs();
      const waitingJobs = await schedulerQueue.getWaiting();
      const activeJobs = await schedulerQueue.getActive();
      
      return {
        ok: true,
        schedulersActive: repeatJobs.length > 0,
        repeatableJobs: repeatJobs.length,
        waitingJobs: waitingJobs.length,
        activeJobs: activeJobs.length,
        repeatable: repeatJobs.map(j => ({
          key: j.key,
          name: j.name,
          pattern: j.pattern,
          next: j.next,
        })),
      };
    } catch (err: any) {
      return reply.code(500).send({ error: err.message, stack: err.stack });
    }
  });

  /**
   * 🧪 TEST: Generate morning brief NOW
   */
  fastify.post('/api/v1/test/brief', async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.code(404).send({ error: 'User not found' });
      }

      // ✅ Use the REAL consciousness system (same as scheduler)
      const text = await aiService.generateMorningBrief(userId);

      // Create CoachMessage instead of Event
      const message = await coachMessageService.createMessage(userId, 'brief', text, { source: 'test' });

      console.log(`✅ Test morning brief generated for ${userId}`);
      return { ok: true, message: text, id: message.id };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 🧪 TEST: Generate evening debrief NOW
   */
  fastify.post('/api/v1/test/debrief', async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.code(404).send({ error: 'User not found' });
      }

      // ✅ Use the REAL consciousness system (same as scheduler)
      const text = await aiService.generateEveningDebrief(userId);

      // Create CoachMessage instead of Event (using 'mirror' kind for debrief)
      const message = await coachMessageService.createMessage(userId, 'mirror', text, { source: 'test' });

      console.log(`✅ Test evening debrief generated for ${userId}`);
      return { ok: true, message: text, id: message.id };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 🧪 TEST: Generate nudge NOW
   */
  fastify.post('/api/v1/test/nudge', async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.code(404).send({ error: 'User not found' });
      }

      const reason = req.body?.reason || 'testing nudge system';
      
      // ✅ Use the REAL consciousness system (same as scheduler)
      const text = await aiService.generateNudge(userId, reason);

      // Create CoachMessage instead of Event
      const message = await coachMessageService.createMessage(userId, 'nudge', text, { source: 'test', reason });

      console.log(`✅ Test nudge generated for ${userId}`);
      return { ok: true, message: text, id: message.id };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message });
    }
  });

  /**
   * 🧪 TEST: Generate ALL messages (brief + debrief + nudge)
   */
  fastify.post('/api/v1/test/generate-all', async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        // Create user if doesn't exist
        await prisma.user.create({
          data: {
            id: userId,
            email: `${userId}@test.com`,
          },
        });
        console.log(`✅ Created test user: ${userId}`);
      }

      const { nudgesService } = await import('../services/nudges.service');
      const { insightsService } = await import('../services/insights.service');

      // 1. Generate morning brief
      const habits = await prisma.habit.findMany({ where: { userId } });
      const recent = await prisma.event.findMany({
        where: { userId },
        orderBy: { ts: 'desc' },
        take: 50,
      });

      const briefPrompt = `Morning brief. Set 2–3 actionable orders for today.`;
      const briefText = await aiService.generateFutureYouReply(userId, briefPrompt, { 
        purpose: 'brief', 
        maxChars: 500 
      });
      // Create CoachMessage instead of Event
      await coachMessageService.createMessage(userId, 'brief', briefText, { source: 'test' });

      // 2. Generate evening debrief
      const kept = recent.filter(e => e.type === 'habit_action' && (e.payload as any)?.completed === true).length;
      const missed = recent.filter(e => e.type === 'habit_action' && (e.payload as any)?.completed === false).length;
      const debriefPrompt = `Evening debrief. Kept=${kept}, Missed=${missed}. Reflect and give 1 order for tomorrow.`;
      const debriefText = await aiService.generateFutureYouReply(userId, debriefPrompt, { 
        purpose: 'debrief', 
        maxChars: 500 
      });
      // Create CoachMessage instead of Event (using 'mirror' kind for debrief)
      await coachMessageService.createMessage(userId, 'mirror', debriefText, { source: 'test' });

      // 3. Generate smart nudge
      const nudgeResult = await nudgesService.generateNudges(userId);

      // 4. Generate insights
      const insights = await insightsService.analyzePatterns(userId);

      console.log(`✅ Generated ALL messages for ${userId}`);
      return { 
        ok: true, 
        brief: briefText,
        debrief: debriefText,
        nudge: nudgeResult,
        insightsCount: insights.length,
      };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message, stack: err.stack });
    }
  });

  /**
   * 🧠 TEST: Manually trigger pattern learning NOW
   */
  fastify.post('/api/v1/test/pattern-learning', async (req: any, reply) => {
    try {
      console.log(`🧠 PATTERN LEARNING RUN - Manual trigger via test endpoint`);
      
      // Dynamic import to match scheduler pattern
      const { patternLearningWorker } = await import("../workers/pattern-learning.worker");
      const result = await patternLearningWorker.processAllUsers();
      
      console.log(`🧠 PATTERN LEARNING RUN - Manual test complete`);
      
      return {
        ok: true,
        processed: result.processed,
        errors: result.errors,
        message: `Pattern learning complete: ${result.processed} users processed, ${result.errors} errors`
      };
    } catch (err: any) {
      const code = err.statusCode || 500;
      return reply.code(code).send({ error: err.message, stack: err.stack });
    }
  });
}

