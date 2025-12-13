<!-- 1134b9b7-e26b-482a-a8a2-b4fb373e2605 27ea3330-69f1-4c0b-8ebd-a0d8a64b037e -->
# 







































































































Add method to query past reflFile: backend/src/services/memory-synthesis.service.tsStep 4: Add Chroma Query to Memory SynthesisSame pattern as Step 1const systemPrompt = this.buildSystemPrompt(synthesis.voiceCalibration, synthesis.phase);Change line 424:File: backend/src/services/coach-engine.service.tsStep 3: Update generateWeeklyLetter() to use buildSystemPromptV2Same pattern as Step 1const systemPrompt = this.buildSystemPrompt(synthesis.voiceCalibration, synthesis.phase);Change line 360:File: backend/src/services/coach-engine.service.tsStep 2: Update generateNudge() to use buildSystemPromptV2To use buildSystemPromptV2 with validation/retry loop like generateBrief()const systemPrompt = this.buildSystemPrompt(synthesis.voiceCalibration, synthesis.phase);Change line 391:File: backend/src/services/coach-engine.service.tsStep 1: Update generateDebrief() to use buildSystemPromptV2FIX PLAN---Should be replaced with "Bro" per user's gold standardAll 48 examples in voice-examples.ts use [NAME]Failure 7: Voice Examples Use "[NAME]" but User Wants "Bro"Does NOT factor in reflection count or pattern confidencecomputeAuthority() only uses daysInSystem and dataQualityFailure 6: Authority NOT Evolving Based on Reflections AnsweredBut memory-synthesis.service.ts does NOT query Redis for execution stateRedis tracks short-term memory in memory-intelligence.service.tsFailure 5: Redis Execution State NOT Influencing ToneOthers generate once and return whatever LLM producesOnly generateBrief() has validation + 2-attempt retryFailure 4: No Validation/Retry on Debrief, Nudge, Letter, ChatNEITHER uses coach-engine or gold standard voicefuture-you-v2.service.ts (emotion-aware) - Registered at /api/os/chat/v2future-you-chat.service.ts (7-lens discovery) - Registered at /api/os/chatFailure 3: Two Chat Paths with Different BrainsAI cannot say "You said last week..." because it doesn't have accessReflections are stored but NEVER injected into promptsmemory-synthesis.service.ts has ZERO calls to semanticMemory.queryMemories()Failure 2: Chroma Memories NOT Retrieved for PromptsgenerateNudge(), generateDebrief(), generateWeeklyLetter(), generateChatResponse() use OLD buildSystemPromptONLY generateBrief() uses buildSystemPromptV2 with gold examplesFailure 1: Gold Standard Voice NOT Enforced (4 of 5 methods)DIAGNOSIS: 7 CRITICAL FAILURES---Used in prompts: NO - the new pipeline (memory-synthesis) does NOT query ChromaQueried: memory-intelligence.service.ts line 214 queries itWritten to: YES (reflections, briefs, debriefs in ai.service.v2.ts)F. Chroma StatusBUT NEVER QUERIED FOR PROMPTS - memory-synthesis.service.ts has ZERO calls to semanticMemoryChroma semantic memory - SAVED (reflections.controller.ts line 64)Postgres Event table (type: "reflection_answer") - SAVEDE. Reflection Storageweekly-consolidation (Sunday midnight) - Uses insightsServicepattern-learning (3am) - Uses patternLearningWorker nudge (10am, 2pm, 6pm) - Uses aiServiceV2 evening-debrief (9pm) - Uses aiServiceV2 daily-brief (7am) - Uses aiServiceV2 D. Scheduler Jobs Runningmemory-intelligence.service.ts - Used by deep-user-model, but its Chroma query results NOT passed to promptsbuildSystemPrompt() - Used by 4 of 5 generation methods (NOT brief)ai.service.ts - Used as fallback when aiServiceV2 failsC. Legacy Services Still Activenudges.service.ts.generateNudges() - Only called by auto-nudges which is disabledbrief.service.ts - Not used by schedulerai-os-prompts.service.ts - Only imported by legacy ai.service.tsB. Dead Code| Chat | future-you-chat.service.ts OR future-you-v2.service.ts | SEPARATE prompt systems, NO gold standard || Weekly Letter | scheduler.ts -> insightsService -> coachEngine.generateWeeklyLetter() | buildSystemPrompt WITHOUT gold examples || Debriefs | scheduler.ts -> aiServiceV2 -> coachEngine.generateDebrief() | buildSystemPrompt WITHOUT gold examples || Nudges | scheduler.ts -> aiServiceV2 -> coachEngine.generateNudge() | buildSystemPrompt WITHOUT gold examples || Morning Brief | scheduler.ts -> aiServiceV2 -> coachEngine.generateBrief() | buildSystemPromptV2 WITH gold examples ||--------------|----------------|--------------|







Step 7: Update Voice Examples to Use "Bro"



File: backend/src/services/voice-examples.ts







Replace all [NAME] with Bro to match user's gold standard examples







Step 8: Update computeAuthority() to Factor Reflections



File: backend/src/services/coach-engine.service.ts







Add reflection count to authority calculation:







private computeAuthority(synthesis: any): "humble" | "growing" | "earned" | "deep" {



  const daysInSystem = synthesis.daysInSystem || 0;



  const dataQuality = synthesis.voiceCalibration?.dataQuality || "sparse";



  const reflectionCount = synthesis.reflectionCount || 0;



  



  // Factor in reflections answered



  if (reflectionCount > 20 && daysInSystem > 30) return "earned";



  // ... rest of logic



}



Step 9: Mark Legacy Services as Deprecated



File: backend/src/services/ai.service.ts







File: backend/src/services/ai-os-prompts.service.ts







Add deprecation notices but do NOT delete (they're fallbacks)







---







SUCCESS CRITERIA



After fixes:







Morning brief uses real habits + gold standard voice



Debrief references today's actual completions



Nudges include streak data



AI says "You told me..." referencing past reflections



Authority evolves from humble -> growing -> earned -> deep



No banned phrases appear in output



All outputs end with reflection questions



One canonical chat path exists

### To-dos

- [ ] Update generateDebrief() to use buildSystemPromptV2 with validation/retry
- [ ] Update generateNudge() to use buildSystemPromptV2 with validation/retry
- [ ] Update generateWeeklyLetter() to use buildSystemPromptV2 with validation/retry
- [ ] Add getRelevantReflections() to memory-synthesis to query Chroma
- [ ] Inject past reflections into brief/debrief prompts
- [ ] Route chat to coachEngine.generateChatResponse()
- [ ] Replace [NAME] with Bro in voice-examples.ts
- [ ] Update computeAuthority() to factor in reflection count