import { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import { MultipartFile } from "@fastify/multipart";
import OpenAI from "openai";
import fs from "fs";
import path from "path";
import { Readable } from "stream";
import { voiceService } from "../services/voice.service";

const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";

function getOpenAIClient() {
  if (process.env.NODE_ENV === "build" || process.env.RAILWAY_ENVIRONMENT === "build") return null;
  if (!process.env.OPENAI_API_KEY) return null;
  const apiKey = process.env.OPENAI_API_KEY.trim();
  return new OpenAI({ apiKey });
}

/**
 * 🎤 SPEECH CONTROLLER
 * Handles speech-to-text using OpenAI Whisper
 */
export async function speechController(fastify: FastifyInstance) {
  /**
   * POST /api/v1/speech/transcribe
   * Accepts audio file and returns transcribed text
   */
  fastify.post("/transcribe", async (req: any, reply: FastifyReply) => {
    const userId = req.headers["x-user-id"] as string;

    if (!userId) {
      return reply.status(401).send({ error: "User ID required" });
    }

    const openai = getOpenAIClient();
    if (!openai) {
      return reply.status(503).send({ error: "OpenAI service unavailable" });
    }

    try {
      // Get the uploaded file from multipart form data
      const data = await req.file();
      
      if (!data) {
        return reply.status(400).send({ error: "No audio file provided" });
      }

      // Create a temporary file to store the audio
      const tempDir = path.join(process.cwd(), "tmp");
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      const tempFilePath = path.join(tempDir, `audio-${userId}-${Date.now()}.webm`);
      const writeStream = fs.createWriteStream(tempFilePath);

      // Pipe the file data to the temp file
      await new Promise((resolve, reject) => {
        data.file.pipe(writeStream);
        data.file.on("end", resolve);
        data.file.on("error", reject);
      });

      console.log(`📝 Transcribing audio file: ${tempFilePath}`);

      // Transcribe using OpenAI Whisper
      const transcription = await openai.audio.transcriptions.create({
        file: fs.createReadStream(tempFilePath),
        model: "whisper-1",
        language: "en", // Can be made dynamic
        response_format: "text",
      });

      // Clean up temp file
      fs.unlinkSync(tempFilePath);

      console.log(`✅ Transcription complete: "${transcription}"`);

      return reply.send({
        text: transcription,
        success: true,
      });

    } catch (err: any) {
      console.error("❌ Transcription failed:", err);
      return reply.status(500).send({ 
        error: err.message || "Transcription failed",
        success: false,
      });
    }
  });

  /**
   * GET /api/v1/speech/voices
   * Get available TTS voices
   */
  fastify.get("/voices", async (req: FastifyRequest, reply: FastifyReply) => {
    const voices = voiceService.getAvailableVoices();
    const defaultVoice = voiceService.getDefaultVoice();

    return reply.send({
      voices,
      default: defaultVoice,
    });
  });

  /**
   * GET /api/v1/speech/test
   * Test endpoint to verify speech controller is registered
   */
  fastify.get("/test", async (req: FastifyRequest, reply: FastifyReply) => {
    return reply.send({ 
      message: "Speech controller active",
      whisper_available: !!getOpenAIClient(),
    });
  });
}

