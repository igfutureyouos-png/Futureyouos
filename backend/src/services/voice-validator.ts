// =============================================================================
// VOICE VALIDATOR SERVICE
// =============================================================================

import { BANNED_PHRASES, containsBannedPhrase } from "./voice-examples";

export interface ValidationResult {
  passed: boolean;
  violations: string[];
  severity: "none" | "minor" | "major" | "critical";
  suggestions: string[];
}

export interface ValidationOptions {
  messageType: "brief" | "nudge" | "debrief" | "letter" | "chat";
  userName?: string;
  strictMode?: boolean;
}

const VALIDATION_RULES = {
  minQuestions: {
    brief: 2,
    debrief: 2,
    nudge: 0,
    letter: 1,
    chat: 0,
  },
  maxLength: {
    brief: 1500,
    debrief: 1500,
    nudge: 350,
    letter: 2500,
    chat: 1000,
  },
  minLength: {
    brief: 200,
    debrief: 200,
    nudge: 50,
    letter: 400,
    chat: 20,
  },
};

const GENERIC_INDICATORS = [
  "as an ai",
  "i don't have personal",
  "i cannot",
  "i'm here to help",
  "let me know if",
  "feel free to",
  "happy to help",
  "that's a great",
  "great question",
  "absolutely",
  "certainly",
];

const VALID_STARTS = [
  /^[A-Z][a-z]+[,…\s]/,
  /^bro/i,
  /^listen/i,
  /^hey/i,
  /^look/i,
  /^alright/i,
  /^today/i,
  /^yesterday/i,
  /^this week/i,
];

export function validateOutput(
  text: string,
  options: ValidationOptions
): ValidationResult {
  const violations: string[] = [];
  const suggestions: string[] = [];
  const { messageType, userName, strictMode = false } = options;
  
  const trimmedText = text.trim();
  const lowerText = trimmedText.toLowerCase();
  
  // Check banned phrases
  const bannedPhrase = containsBannedPhrase(trimmedText);
  if (bannedPhrase) {
    violations.push(`BANNED_PHRASE: Contains "${bannedPhrase}"`);
    suggestions.push(`Remove or rephrase "${bannedPhrase}"`);
  }
  
  // Check generic AI indicators
  for (const indicator of GENERIC_INDICATORS) {
    if (lowerText.includes(indicator)) {
      violations.push(`GENERIC_AI: Contains "${indicator}"`);
    }
  }
  
  // Check question requirements
  const questionCount = (trimmedText.match(/\?/g) || []).length;
  const minQuestions = VALIDATION_RULES.minQuestions[messageType];
  
  if (questionCount < minQuestions) {
    violations.push(`MISSING_QUESTIONS: Found ${questionCount}, need ${minQuestions}`);
  }
  
  // Check length
  const maxLength = VALIDATION_RULES.maxLength[messageType];
  const minLength = VALIDATION_RULES.minLength[messageType];
  
  if (trimmedText.length > maxLength) {
    violations.push(`TOO_LONG: ${trimmedText.length} chars exceeds ${maxLength}`);
  }
  
  if (trimmedText.length < minLength) {
    violations.push(`TOO_SHORT: ${trimmedText.length} chars below ${minLength}`);
  }
  
  // Check direct address
  if (messageType !== "chat") {
    const hasValidStart = VALID_STARTS.some((pattern) => pattern.test(trimmedText));
    const startsWithName = userName && trimmedText.toLowerCase().startsWith(userName.toLowerCase());
    
    if (!hasValidStart && !startsWithName) {
      violations.push(`MISSING_DIRECT_ADDRESS: Should start with name`);
    }
  }
  
  // Check name usage
  if (userName && messageType !== "nudge") {
    const nameCount = (trimmedText.match(new RegExp(userName, "gi")) || []).length;
    if (nameCount === 0) {
      violations.push(`MISSING_NAME: User's name not used`);
    }
  }
  
  // Check placeholders
  if (/\[NAME\]|\[HABIT\]|\[STREAK\]/.test(trimmedText)) {
    violations.push(`UNFILLED_PLACEHOLDER: Contains unfilled placeholder`);
  }
  
  // Calculate severity
  let severity: ValidationResult["severity"] = "none";
  if (violations.length > 0) {
    const hasBanned = violations.some((v) => v.startsWith("BANNED_PHRASE"));
    const hasGeneric = violations.some((v) => v.startsWith("GENERIC_AI"));
    
    if (hasBanned || hasGeneric) {
      severity = "critical";
    } else if (violations.length >= 3) {
      severity = "major";
    } else {
      severity = "minor";
    }
  }
  
  return { passed: violations.length === 0, violations, severity, suggestions };
}

export function quickValidate(text: string): boolean {
  const lowerText = text.toLowerCase();
  
  for (const phrase of BANNED_PHRASES) {
    if (lowerText.includes(phrase.toLowerCase())) return false;
  }
  
  for (const indicator of GENERIC_INDICATORS) {
    if (lowerText.includes(indicator)) return false;
  }
  
  return true;
}

export function generateViolationFeedback(result: ValidationResult): string {
  if (result.passed) return "";
  return `⚠️ VIOLATIONS:\n${result.violations.map(v => `- ${v}`).join("\n")}`;
}

export function cleanOutput(text: string, userName?: string): string {
  let cleaned = text.trim();
  
  // Remove AI filler
  cleaned = cleaned.replace(/^(I'd be happy to |I can help |Let me |Here's |Sure,? )/i, "");
  
  // Replace [NAME]
  if (userName) {
    cleaned = cleaned.replace(/\[NAME\]/g, userName);
  }
  
  // Fix spacing
  cleaned = cleaned.replace(/\n{3,}/g, "\n\n");
  
  return cleaned.trim();
}

export const voiceValidator = {
  validate: validateOutput,
  quickValidate,
  generateFeedback: generateViolationFeedback,
  clean: cleanOutput,
};

