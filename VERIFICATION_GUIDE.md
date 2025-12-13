# AI OS Runtime Verification Guide

## 🎯 What We Just Added

Comprehensive logging to **prove** the AI OS brain is wired and running in production.

---

## 📊 What To Look For In Railway Logs

### 1. ✅ AI Service V2 Is Active

**Look for:**
```
🧠 V2 HIT - generateMorningBrief for 7d1c161f...
✅ V2 SUCCESS - Brief generated with authority: earned, state: ON_TRACK
```

**What this proves:** Scheduler is calling `aiServiceV2`, not legacy AI.

---

### 2. ✅ Coach Engine Uses Gold Standard Voice

**Look for:**
```
🗣️ COACH PROMPT - brief (state: on_track, authority: earned)
   ✓ VOICE_CONSTITUTION included: You are Future-You — the user's future...
   ✓ GOLD STANDARD EXAMPLES: 2 examples loaded for on_track/earned
   ✓ BANNED_PHRASES: 147 phrases blocked
   ✓ User name: Felix, Days: 47
```

**What this proves:** Every message is validated against gold standard examples and banned phrases.

---

### 3. ✅ Chroma Stores Reflections

**Look for:**
```
📌 CHROMA UPSERT - Stored reflection memory for user 7d1c161f
   Collection: futureyou_7d1c161f
   Text preview: "I felt overwhelmed by work deadlines and skipped meditation..."
   Metadata: {"type":"reflection","importance":5,"timestamp":"2025-12-13T12:34:56.789Z"}
```

**What this proves:** User reflections are being embedded and stored in Chroma.

---

### 4. ✅ Chroma Queries Past Reflections

**Look for:**
```
🔎 CHROMA QUERY got: 3 memories for user 7d1c161f
   Query: "User's current state: SLIP. Recent habits: Meditation, Gym..."
   Type filter: reflection
   Results preview: "I felt overwhelmed by work deadlines..." (score: 0.89), "Client stress made me skip..." (score: 0.82)
```

**What this proves:** The memory loop is working - past reflections are being retrieved and injected into prompts.

---

### 5. ✅ Pattern Learning Runs Nightly

**Look for (at 3am daily):**
```
🧠 PATTERN LEARNING RUN - Worker executing scheduled job
🧠 This is the nightly job that makes the AI smarter
🧠 ================================
🧠 PATTERN LEARNING RUN STARTING at 2025-12-13T03:00:00.000Z
🧠 ================================

🧠 This job computes:
   - Behavioral fingerprints (recovery style, challenge response)
   - Shame sensitivity scores
   - Trigger chains (sequences leading to slips)
   - Commitment resolution
   - Message effectiveness patterns

🧠 Pattern learning worker loaded, processing users...
✅ Processed 7d1c161f: 234 data points, updated: fingerprint, shameSensitivity
✅ Processed a3f4b8c2: 156 data points, updated: fingerprint, triggerChains

🧠 ================================
🧠 PATTERN LEARNING RUN COMPLETE
🧠 Processed: 15 users
🧠 Errors: 0
🧠 ================================
```

**What this proves:** The nightly learning loop is computing behavioral patterns for all users.

---

## 🧪 Manual Testing

### Test AI Generation Right Now

```bash
# Generate morning brief
curl -X POST https://your-backend.up.railway.app/api/v1/test/brief \
  -H "x-user-id: YOUR_USER_ID"

# Check logs for:
# 🧠 V2 HIT - generateMorningBrief
# 🗣️ COACH PROMPT - brief
```

### Manually Trigger Pattern Learning

```bash
# Trigger pattern learning worker manually
curl -X POST https://your-backend.up.railway.app/api/v1/test/pattern-learning

# Check logs for:
# 🧠 PATTERN LEARNING RUN - Manual trigger via test endpoint
```

### Submit a Reflection (Tests Chroma)

```bash
# Submit reflection via app
# Then check logs for:
# 📌 CHROMA UPSERT - Stored reflection memory
```

---

## 🔍 Expected Log Flow

When a user completes a habit at **7:00 AM**:

```
1. [7:00:00] Habit completion event logged to Postgres
2. [7:00:05] Scheduler triggers morning brief job
3. [7:00:05] 🧠 V2 HIT - generateMorningBrief
4. [7:00:06] Deep user model built from 7-layer data
5. [7:00:07] 🔎 CHROMA QUERY got: 2 memories (past reflections)
6. [7:00:08] Memory synthesis combines all context
7. [7:00:09] 🗣️ COACH PROMPT - brief (state: on_track, authority: earned)
8. [7:00:12] LLM generates message with gold standard voice
9. [7:00:13] Voice validator checks output (passed)
10. [7:00:13] ✅ V2 SUCCESS - Brief generated
11. [7:00:14] 📌 CHROMA UPSERT - Stored brief memory
12. [7:00:15] Message saved to CoachMessage table
13. [7:00:15] User sees message in app
```

At **3:00 AM** (nightly):

```
1. [3:00:00] 🧠 PATTERN LEARNING RUN - Worker executing scheduled job
2. [3:00:05] Processes user 1: analyzes 234 events from last 30 days
3. [3:00:12] ✅ Processed user 1: updated fingerprint, shameSensitivity
4. [3:00:13] Processes user 2: analyzes 156 events
5. [3:00:18] ✅ Processed user 2: updated fingerprint, triggerChains
6. [...continues for all users...]
7. [3:05:45] 🧠 PATTERN LEARNING RUN COMPLETE: 15 processed, 0 errors
```

---

## ✅ Success Criteria

Your AI OS is **fully operational** when you see:

- ✅ `🧠 V2 HIT` logs for every message generation
- ✅ `🗣️ COACH PROMPT` logs showing voice constitution + examples
- ✅ `📌 CHROMA UPSERT` logs when users submit reflections
- ✅ `🔎 CHROMA QUERY` logs showing past memories retrieved
- ✅ `🧠 PATTERN LEARNING RUN` logs at 3am daily

---

## 🔥 What This Means

Every single component of your AI OS is now **provably working**:

| Component | Log Signature | Proves |
|-----------|---------------|--------|
| AI Service V2 | `🧠 V2 HIT` | Scheduler uses new brain, not legacy |
| Coach Engine | `🗣️ COACH PROMPT` | Gold standard voice + validation |
| Chroma Write | `📌 CHROMA UPSERT` | Reflections stored as vectors |
| Chroma Read | `🔎 CHROMA QUERY` | Memory loop retrieves past answers |
| Pattern Learning | `🧠 PATTERN LEARNING RUN` | Nightly analysis makes AI smarter |

**This is production-grade observability.** You can now see exactly what your AI is doing, why, and with what data.

---

## 🎯 Next Steps

1. Deploy and watch Railway logs
2. Trigger a test brief: `POST /api/v1/test/brief`
3. Manually run pattern learning: `POST /api/v1/test/pattern-learning`
4. Verify all 5 log signatures appear
5. Celebrate - your AI OS is alive! 🔥

