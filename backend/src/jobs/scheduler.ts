// src/jobs/scheduler.ts
// 🧠 OS brain-only scheduler: briefs, debriefs, nudges, and weekly insights

import { Queue, Worker, JobsOptions } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { aiService } from "../services/ai.service";
import { aiServiceV2 } from "../services/ai.service.v2";
import { coachMessageService } from "../services/coach-message.service";
import { notificationsService } from "../services/notifications.service";
import { voiceService } from "../services/voice.service";
import { nudgesService } from "../services/nudges.service";
import { premiumService } from "../services/premium.service";

const QUEUE = "scheduler";
export const schedulerQueue = new Queue(QUEUE, { connection: redis });

const PRO_FEATURES_ENABLED =
  (process.env.PRO_FEATURES_ENABLED || "true").toLowerCase() === "true";
const FREE_NOTIFICATIONS_ENABLED =
  (process.env.FREE_NOTIFICATIONS_ENABLED || "false").toLowerCase() === "true";

// Re-usable hourly repeat options (for ensure-* + auto-nudges-hourly)
function repeatHourly(): JobsOptions {
  return {
    repeat: { every: 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  };
}

// 🔌 Called from app bootstrap
export async function bootstrapSchedulers() {
  console.log("⏰ Schedulers active (OS brain only)");

  // Re-upsert daily brief / debrief / nudge schedules per user (respect tz)
  // Run every 6 hours instead of hourly to prevent duplicate job creation
  await schedulerQueue.add("ensure-daily-briefs", {}, {
    repeat: { every: 6 * 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  });
  await schedulerQueue.add("ensure-evening-debriefs", {}, {
    repeat: { every: 6 * 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  });
  await schedulerQueue.add("ensure-nudges", {}, {
    repeat: { every: 6 * 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  });

  // REMOVED: auto-nudges-hourly - this was causing duplicate nudges
  // We already have scheduled nudges at 10am, 2pm, and 6pm via ensure-nudges

  // Weekly memory consolidation (Sundays at midnight)
  await schedulerQueue.add("weekly-consolidation", {}, {
    repeat: { pattern: "0 0 * * 0" }, // Sunday 00:00
    removeOnComplete: true,
    removeOnFail: true,
  });

  // 🧠 Pattern learning (3am daily) - CRITICAL for AI OS brain
  // This job computes behavioral fingerprints, shame sensitivity, trigger chains
  // Without this, the AI never learns the user's patterns
  await schedulerQueue.add("pattern-learning", {}, {
    repeat: { pattern: "0 3 * * *" }, // 3am daily
    removeOnComplete: true,
    removeOnFail: true,
  });
  console.log("🧠 Pattern learning job scheduled (3am daily)");
}

// ─────────────────────────────────────────────
// JOB DEFINITIONS
// ─────────────────────────────────────────────

async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || "Europe/London";
    await schedulerQueue.add(
      "daily-brief",
      { userId: u.id },
      {
        repeat: { pattern: "0 7 * * *", tz },
        jobId: `daily-brief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
  return { ok: true, users: users.length };
}

async function ensureEveningDebriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || "Europe/London";
    await schedulerQueue.add(
      "evening-debrief",
      { userId: u.id },
      {
        repeat: { pattern: "0 21 * * *", tz },
        jobId: `evening-debrief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
  return { ok: true, users: users.length };
}

async function ensureNudgeJobs() {
  console.log(`\n🔧 ensureNudgeJobs STARTING at ${new Date().toISOString()}`);
  
  const users = await prisma.user.findMany({
    select: { id: true, tz: true, nudgesEnabled: true },
  });
  
  console.log(`🔧 Found ${users.length} total users, filtering for nudgesEnabled...`);

  let enabledCount = 0;
  for (const u of users) {
    if (!u.nudgesEnabled) continue;
    enabledCount++;
    
    const tz = u.tz || "Europe/London";
    console.log(`🔧 Processing user ${u.id} (tz: ${tz})`);

    // Remove existing nudge jobs for this user to prevent duplicates
    const jobIds = [
      `nudge-morning:${u.id}`,
      `nudge-afternoon:${u.id}`,
      `nudge-evening:${u.id}`,
    ];
    
    for (const jobId of jobIds) {
      try {
        const job = await schedulerQueue.getJob(jobId);
        if (job) {
          console.log(`🗑️ Removing existing job: ${jobId}`);
          await job.remove();
        }
      } catch (err) {
        // Job doesn't exist, that's fine
      }
    }

    // Morning nudge (10am)
    await schedulerQueue.add(
      "nudge",
      { userId: u.id, trigger: "morning_momentum" },
      {
        repeat: { pattern: "0 10 * * *", tz },
        jobId: `nudge-morning:${u.id}`,
        removeOnComplete: { count: 10 }, // Keep last 10 for debugging
        removeOnFail: { count: 10 },
      }
    );
    console.log(`✅ Scheduled morning nudge for ${u.id}`);

    // Afternoon nudge (2pm)
    await schedulerQueue.add(
      "nudge",
      { userId: u.id, trigger: "afternoon_drift" },
      {
        repeat: { pattern: "0 14 * * *", tz },
        jobId: `nudge-afternoon:${u.id}`,
        removeOnComplete: { count: 10 },
        removeOnFail: { count: 10 },
      }
    );
    console.log(`✅ Scheduled afternoon nudge for ${u.id}`);

    // Evening nudge (6pm)
    await schedulerQueue.add(
      "nudge",
      { userId: u.id, trigger: "evening_closeout" },
      {
        repeat: { pattern: "0 18 * * *", tz },
        jobId: `nudge-evening:${u.id}`,
        removeOnComplete: { count: 10 },
        removeOnFail: { count: 10 },
      }
    );
    console.log(`✅ Scheduled evening nudge for ${u.id}`);
  }
  
  console.log(`🔧 ensureNudgeJobs COMPLETE: ${enabledCount} users with nudges enabled\n`);
  return { ok: true, users: users.length };
}

async function runDailyBrief(userId: string) {
  // 🔒 PAYWALL: Only send briefs to premium users
  const isPremium = await premiumService.isPremium(userId);
  if (!isPremium) {
    console.log(`⏭️ Skipping morning brief for free user: ${userId}`);
    return { ok: true, skipped: true, reason: "not_premium" };
  }

  // 🧠 AI OS v2: Use new coach engine with fallback to legacy
  let text: string;
  try {
    console.log(`🧠 [AI OS v2] Generating morning brief for ${userId}...`);
    text = await aiServiceV2.generateMorningBrief(userId);
    console.log(`✅ [AI OS v2] Morning brief generated successfully`);
  } catch (err) {
    console.warn(`⚠️ [AI OS v2] Failed, falling back to legacy:`, err);
    text = await aiService.generateMorningBrief(userId).catch(() => "Good morning.");
  }

  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, "future-you");
  } catch {
    audioUrl = null;
  }

  // Store as CoachMessage (kind = brief)
  await coachMessageService.createMessage(userId, "brief", text, { audioUrl });

  // Backwards compat event
  await prisma.event.create({
    data: { userId, type: "morning_brief", payload: { text, audioUrl } },
  });

  await notificationsService.send(userId, "Morning Brief", text.slice(0, 180));
  return { ok: true };
}

async function runEveningDebrief(userId: string) {
  // 🔒 PAYWALL: Only send debriefs to premium users
  const isPremium = await premiumService.isPremium(userId);
  if (!isPremium) {
    console.log(`⏭️ Skipping evening debrief for free user: ${userId}`);
    return { ok: true, skipped: true, reason: "not_premium" };
  }

  // 🧠 AI OS v2: Use new coach engine with fallback to legacy
  let text: string;
  try {
    console.log(`🧠 [AI OS v2] Generating evening debrief for ${userId}...`);
    text = await aiServiceV2.generateEveningDebrief(userId);
    console.log(`✅ [AI OS v2] Evening debrief generated successfully`);
  } catch (err) {
    console.warn(`⚠️ [AI OS v2] Failed, falling back to legacy:`, err);
    text = await aiService.generateEveningDebrief(userId).catch(() => "Evening debrief.");
  }

  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, "future-you");
  } catch {
    audioUrl = null;
  }

  // Store as CoachMessage (kind = debrief)
  await coachMessageService.createMessage(userId, "debrief", text, { audioUrl });

  // Backwards compat event
  await prisma.event.create({
    data: { userId, type: "evening_debrief", payload: { text, audioUrl } },
  });

  await notificationsService.send(userId, "Evening Debrief", text.slice(0, 180));
  return { ok: true };
}

async function runNudge(userId: string, trigger: string) {
  // 🔒 PAYWALL: Only send nudges to premium users
  // TEMP: Disabled for testing - re-enable before production launch
  // const isPremium = await premiumService.isPremium(userId);
  // if (!isPremium) {
  //   console.log(`⏭️ Skipping nudge for free user: ${userId}`);
  //   return { ok: true, skipped: true, reason: "not_premium" };
  // }

  const timestamp = new Date().toISOString();
  console.log(`\n🔔 ================================`);
  console.log(`🔔 runNudge CALLED`);
  console.log(`🔔 Time: ${timestamp}`);
  console.log(`🔔 User: ${userId}`);
  console.log(`🔔 Trigger: ${trigger}`);
  console.log(`🔔 ================================\n`);
  
  // ✅ ANTI-DUPLICATE CHECK: Don't send another nudge if one was just sent
  const recentNudges = await prisma.coachMessage.findMany({
    where: {
      userId,
      kind: "nudge",
      createdAt: {
        gte: new Date(Date.now() - 15 * 60 * 1000), // Last 15 minutes
      },
    },
    orderBy: { createdAt: "desc" },
    take: 1,
  });

  if (recentNudges.length > 0) {
    console.log(`⚠️ DUPLICATE NUDGE PREVENTED - nudge sent ${Math.floor((Date.now() - recentNudges[0].createdAt.getTime()) / 1000 / 60)} minutes ago`);
    return { ok: true, skipped: true, reason: "duplicate_prevention" };
  }
  
  // 🧠 AI OS v2: Use new coach engine with fallback to legacy
  let text: string;
  try {
    console.log(`🧠 [AI OS v2] Generating nudge for ${userId} (trigger: ${trigger})...`);
    text = await aiServiceV2.generateNudge(userId, trigger);
    console.log(`✅ [AI OS v2] Nudge generated successfully`);
  } catch (err) {
    console.warn(`⚠️ [AI OS v2] Failed, falling back to legacy:`, err);
    text = await aiService.generateNudge(userId, trigger).catch(() => "Check in with yourself.");
  }

  console.log(`📝 Generated nudge text: "${text.substring(0, 80)}..."`);

  // Store as CoachMessage (kind = nudge)
  const msg = await coachMessageService.createMessage(userId, "nudge", text, { trigger });
  console.log(`✅ CoachMessage created: ${msg.id}`);

  // Backwards compat event
  const event = await prisma.event.create({
    data: { userId, type: "nudge", payload: { text, trigger } },
  });
  console.log(`✅ Event created: ${event.id}`);

  await notificationsService.send(userId, "Nudge", text.slice(0, 180));
  console.log(`✅ Notification sent`);
  
  console.log(`🔔 runNudge COMPLETED for ${userId}\n`);
  return { ok: true };
}

async function autoNudgesHourly() {
  const users = await prisma.user.findMany({
    select: { id: true, plan: true },
  });

  for (const u of users) {
    if (u.plan !== "PRO" && !FREE_NOTIFICATIONS_ENABLED) continue;

    const res = await nudgesService.generateNudges(u.id);
    const n = Array.isArray(res)
      ? res[0]
      : (res as any).nudges?.[0];

    if (!n?.message) continue;

    await notificationsService.send(
      u.id,
      "Nudge",
      n.message.slice(0, 180)
    );
  }
  return { ok: true };
}

/**
 * 🧠 PATTERN LEARNING - Nightly job that makes the AI OS brain actually learn
 * 
 * This computes:
 * - Behavioral fingerprints (recovery style, challenge response, celebration trap)
 * - Shame sensitivity scores
 * - Trigger chains (sequences that lead to slips)
 * - Message effectiveness patterns
 * 
 * WITHOUT THIS JOB, THE AI NEVER LEARNS USER PATTERNS.
 */
async function runPatternLearning() {
  console.log(`🧠 ================================`);
  console.log(`🧠 PATTERN LEARNING STARTING at ${new Date().toISOString()}`);
  console.log(`🧠 ================================\n`);
  
  try {
    // Dynamic import to avoid circular dependencies
    const { patternLearningWorker } = await import("../workers/pattern-learning.worker");
    const result = await patternLearningWorker.processAllUsers();
    
    console.log(`\n🧠 ================================`);
    console.log(`🧠 PATTERN LEARNING COMPLETE`);
    console.log(`🧠 Processed: ${result.processed} users`);
    console.log(`🧠 Errors: ${result.errors}`);
    console.log(`🧠 ================================\n`);
    
    return result;
  } catch (err) {
    console.error(`❌ Pattern learning failed:`, err);
    return { processed: 0, errors: 1 };
  }
}

async function runWeeklyConsolidation() {
  const users = await prisma.user.findMany({ select: { id: true } });
  console.log(`📅 Running weekly consolidation for ${users.length} users...`);

  for (const u of users) {
    try {
      const { insightsService } = await import("../services/insights.service");
      const result = await insightsService.weeklyConsolidation(u.id);
      if (result.ok) {
        // Notify about weekly letter if generated
        if (result.letterText) {
          await notificationsService.send(
            u.id,
            "📜 Weekly Letter from Future You",
            result.letterText.slice(0, 180)
          );
        } else if (result.reflection) {
          // Fallback to reflection if letter generation failed
          await notificationsService.send(
            u.id,
            "📊 Weekly Insights",
            result.reflection.slice(0, 180)
          );
        }
      }
    } catch (err) {
      console.error(`Failed weekly consolidation for ${u.id}:`, err);
    }
  }

  return { ok: true, processed: users.length };
}

// ─────────────────────────────────────────────
// WORKER - ONLY START WHEN EXPLICITLY CALLED
// ─────────────────────────────────────────────

let workerInstance: Worker | null = null;

/**
 * 🚨 CRITICAL: Start the worker ONLY from worker.ts
 * This prevents duplicate workers when server.ts imports this file
 */
export function startWorker() {
  if (workerInstance) {
    console.log("⚠️ Worker already running, skipping duplicate instantiation");
    return workerInstance;
  }

  console.log("🏭 STARTING SCHEDULER WORKER...");
  
  workerInstance = new Worker(
    QUEUE,
    async (job) => {
      console.log(`\n🏭 WORKER processing job: ${job.name} [ID: ${job.id}] at ${new Date().toISOString()}`);
      if (job.name === "nudge") {
        console.log(`🏭 NUDGE JOB DATA:`, JSON.stringify(job.data));
      }
      
      switch (job.name) {
        case "ensure-daily-briefs":
          return ensureDailyBriefJobs();
        case "ensure-evening-debriefs":
          return ensureEveningDebriefJobs();
        case "ensure-nudges":
          return ensureNudgeJobs();
        case "daily-brief":
          return runDailyBrief(job.data.userId);
        case "evening-debrief":
          return runEveningDebrief(job.data.userId);
        case "nudge":
          console.log(`🏭 WORKER calling runNudge for user ${job.data.userId} with trigger "${job.data.trigger}"`);
          const result = await runNudge(job.data.userId, job.data.trigger);
          console.log(`🏭 WORKER nudge complete for user ${job.data.userId}`);
          return result;
        // REMOVED: auto-nudges-hourly case - no longer used
        case "weekly-consolidation":
          return runWeeklyConsolidation();
        case "pattern-learning":
          console.log(`🧠 WORKER starting pattern learning job...`);
          return runPatternLearning();
        default:
          return;
      }
    },
    { 
      connection: redis,
      // CRITICAL: Ensure only ONE worker processes each job
      concurrency: 1,
    }
  );

  console.log("🧠 Scheduler Worker Started (OS Brain Only)");
  return workerInstance;
}
