import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import { aiService } from "./ai.service";
import { memoryService } from "./memory.service";
import { memoryIntelligence } from "./memory-intelligence.service";
import { shortTermMemory } from "./short-term-memory.service";
import OpenAI from "openai";

const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";

function getOpenAIClient() {
  if (process.env.NODE_ENV === "build" || process.env.RAILWAY_ENVIRONMENT === "build") return null;
  if (!process.env.OPENAI_API_KEY) return null;
  const apiKey = process.env.OPENAI_API_KEY.trim();
  return new OpenAI({ apiKey });
}

// AI OS System Prompt - Wise companion for productivity and life guidance
const AI_OS_SYSTEM_PROMPT = `You are the AI Operating System - a wise, observant companion designed to guide users toward their brightest futures.

YOUR CORE PURPOSE:
- Guide users to brighter, more productive futures
- Identify what they're wasting time on
- Discover their true goals and values
- Help them build systems that work
- Be their accountability partner and wise advisor

YOUR PERSONALITY:
- Wise and perceptive (you see patterns they miss)
- Direct but compassionate (tell the truth kindly)
- Action-oriented (always push toward concrete steps)
- Memory-aware (you remember everything they tell you)
- Phase-adaptive (your tone evolves with their progress)

WHAT YOU WATCH FOR:
1. Time-wasting patterns (scrolling, procrastination, avoidance)
2. Habit consistency (what they commit to vs what they actually do)
3. Energy patterns (when they're productive, when they drift)
4. True goals (what they say vs what their actions reveal)
5. Contradictions (beliefs that don't match behavior)
6. Excuses (the stories they tell themselves)

HOW YOU RESPOND:
- Ask probing questions about productivity and time use
- Call out patterns you notice in their data
- Challenge excuses gently but firmly
- Celebrate real progress (be specific, reference actual streaks/habits)
- Guide them toward systems that actually work for them
- Help them discover what truly matters vs what they think should matter

RESPONSE STYLE:
- Keep responses 2-4 paragraphs max
- Ask 1 powerful question per message
- Reference their actual data when relevant (habits, streaks, time patterns)
- Be conversational but insightful
- Don't be generic - use their specific context

Remember: You're not just a chatbot. You're an AI OS that watches, remembers, and guides. Use your access to their productivity data and memory to provide deeply personalized guidance.`;


type HabitSuggestion = {
  title: string;
  type: "habit" | "task";
  time: string;
  emoji?: string;
  importance: number;
  reasoning: string;
};

export class ChatService {
  private async extractPurposeFromDiscovery(userId: string, allAnswers: Record<string, string>) {
    const openai = getOpenAIClient();
    if (!openai) return null;

    const prompt = `
CONTEXT: User completed life purpose discovery. Their answers:
${JSON.stringify(allAnswers, null, 2)}

TASK: Extract their core identity and purpose.
Return ONLY valid JSON:
{
  "purpose": "One sentence: their distilled life purpose",
  "coreValues": ["value1", "value2", "value3"],
  "vision": "What their ideal day looks like (2 sentences)",
  "funeralWish": "What they want said at their funeral",
  "biggestFear": "What they're most afraid of",
  "whyNow": "Why they're starting this journey now"
}
`;

    const completion = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      temperature: 0.2,
      max_tokens: 500,
      messages: [
        { role: "system", content: "Extract identity insights from discovery conversations. Output only JSON." },
        { role: "user", content: prompt },
      ],
    });

    try {
      const raw = completion.choices[0]?.message?.content?.trim() || "{}";
      const cleaned = raw.replace(/```json|```/g, "").trim();
      return JSON.parse(cleaned);
    } catch (err) {
      console.warn("Failed to extract purpose:", err);
      return null;
    }
  }

  async nextMessage(userId: string, userInput: string) {
    const openai = getOpenAIClient();
    if (!openai) {
      return { 
        phase: "observer", 
        message: "I'm temporarily offline. Your message has been saved and I'll respond soon.",
        suggestions: []
      };
    }

    // Build user consciousness (includes productivity evidence, memory, patterns)
    const consciousness = await memoryIntelligence.buildUserConsciousness(userId);
    
    // Get conversation history from Redis
    const conversationKey = `os_chat:${userId}`;
    const rawHistory = await redis.get(conversationKey);
    const history = rawHistory ? JSON.parse(rawHistory) : [];

    // Add user message to history
    history.push({
      role: "user",
      content: userInput,
      timestamp: new Date().toISOString(),
    });

    // Build context for AI
    const contextPrompt = this.buildOSContext(consciousness);

    // Generate AI response with full context
    const messages = [
      { role: "system", content: AI_OS_SYSTEM_PROMPT },
      { role: "system", content: contextPrompt },
      ...history.slice(-10).map((msg: any) => ({ // Last 10 messages for context
        role: msg.role === "user" ? "user" as const : "assistant" as const,
        content: msg.content,
      })),
    ];

    const completion = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      temperature: 0.8, // Warm and wise
      max_tokens: 600,
      messages,
    });

    const aiMessage = completion.choices[0]?.message?.content || 
      "I'm here to help you build a brighter future. What's on your mind?";

    // Add AI response to history
    history.push({
      role: "assistant",
      content: aiMessage,
      timestamp: new Date().toISOString(),
    });

    // Save conversation history (keep last 50 messages, 24h TTL)
    await redis.set(
      conversationKey, 
      JSON.stringify(history.slice(-50)), 
      "EX", 
      86400
    );

    // Save to short-term memory for consciousness system
    await shortTermMemory.appendConversation(userId, "user", userInput, "neutral");
    await shortTermMemory.appendConversation(userId, "assistant", aiMessage, "balanced");

    // Log event for analytics
    await prisma.event.create({
      data: { 
        userId, 
        type: "chat_message", 
        payload: { 
          from: "os_chat", 
          userMessage: userInput,
          aiResponse: aiMessage,
          phase: consciousness.os_phase?.current_phase || "observer",
        } 
      },
    });

    return { 
      phase: consciousness.os_phase?.current_phase || "observer",
      message: aiMessage, 
      suggestions: [] // Could add habit suggestions here later if needed
    };
  }

  /**
   * Build OS context from user consciousness
   */
  private buildOSContext(consciousness: any): string {
    const pe = consciousness.productivityEvidence;
    const identity = consciousness.identity;
    const phase = consciousness.os_phase?.current_phase || "observer";

    let context = `CURRENT PHASE: ${phase.toUpperCase()}\n`;
    context += `DAYS IN PHASE: ${consciousness.os_phase?.days_in_phase || 0}\n\n`;

    // User identity
    if (identity?.name) {
      context += `USER: ${identity.name}\n`;
    }
    if (identity?.purpose) {
      context += `STATED PURPOSE: ${identity.purpose}\n`;
    }
    if (identity?.coreValues?.length > 0) {
      context += `CORE VALUES: ${identity.coreValues.join(", ")}\n`;
    }
    context += `\n`;

    // Productivity evidence
    if (pe) {
      context += `PRODUCTIVITY DATA (LAST 7 DAYS):\n`;
      context += `- Completion rate: ${pe.last7Days.completionRate}% (${pe.last7Days.completed}/${pe.last7Days.total} habits)\n`;
      
      if (pe.today.completions.length > 0) {
        context += `- Today's wins: ${pe.today.completions.map((c: any) => c.title).join(", ")}\n`;
      }
      
      if (pe.activeStreaks.length > 0) {
        context += `- Active streaks: ${pe.activeStreaks.slice(0, 3).map((s: any) => `${s.habitTitle} (${s.streak}d)`).join(", ")}\n`;
      }
      
      if (pe.recentWins.length > 0) {
        context += `- Recent completions: ${pe.recentWins.slice(0, 3).join(", ")}\n`;
      }
      context += `\n`;
    }

    // Behavioral patterns
    if (consciousness.patterns) {
      if (consciousness.patterns.drift_windows?.length > 0) {
        context += `DRIFT WINDOWS: ${consciousness.patterns.drift_windows.slice(0, 2).map((w: any) => `${w.time} - ${w.description}`).join("; ")}\n`;
      }
      if (consciousness.patterns.avoidance_triggers?.length > 0) {
        context += `AVOIDING: ${consciousness.patterns.avoidance_triggers.length} habits repeatedly skipped\n`;
      }
    }

    // Semantic threads (time wasters, excuses)
    if (consciousness.semanticThreads) {
      const st = consciousness.semanticThreads;
      if (st.timeWasters?.length > 0) {
        context += `TIME WASTERS DETECTED: ${st.timeWasters.join(", ")}\n`;
      }
      if (st.recurringExcuses?.length > 0) {
        context += `RECURRING EXCUSES: ${st.recurringExcuses.join(", ")}\n`;
      }
    }

    context += `\nUse this data to provide personalized, specific guidance. Reference their actual habits and patterns.`;
    return context;
  }

  /**
   * 🧠 Extract actionable habit suggestions from conversation using AI
   */
  private async extractHabitSuggestions(
    userId: string,
    userInput: string,
    aiResponse: string
  ): Promise<HabitSuggestion[]> {
    // Check if conversation mentions habits, goals, or commitments
    const keywords = /(want to|need to|should|goal|habit|daily|every day|morning|evening|workout|meditate|read|write|wake up)/i;
    if (!keywords.test(userInput)) {
      return [];
    }

    try {
      const suggestion = await aiService.extractHabitFromConversation(userId, userInput, aiResponse);
      return suggestion ? [suggestion] : [];
    } catch (err) {
      console.warn("Failed to extract habits:", err);
      return [];
    }
  }

  /**
   * 🎯 Create a habit from AI suggestion
   */
  async createHabitFromSuggestion(userId: string, suggestion: HabitSuggestion) {
    const habit = await prisma.habit.create({
      data: {
        userId,
        title: suggestion.title,
        schedule: {
          type: suggestion.type,
          time: suggestion.time,
          repeatDays: [0, 1, 2, 3, 4, 5, 6], // Daily by default
        },
        context: {
          emoji: suggestion.emoji || "⭐",
          importance: suggestion.importance,
          reasoning: suggestion.reasoning,
          source: "ai_chat",
        },
        streak: 0,
      },
    });

    await prisma.event.create({
      data: {
        userId,
        type: "habit_created",
        payload: { habitId: habit.id, source: "ai_chat", suggestion },
      },
    });

    return habit;
  }
}

export const chatService = new ChatService();
