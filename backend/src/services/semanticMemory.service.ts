// backend/src/services/semanticMemory.service.ts
// Semantic memory layer using Chroma for vector storage
// Gracefully degrades if Chroma is not configured

import { ChromaClient, OpenAIEmbeddingFunction } from "chromadb";
import OpenAI from "openai";

const CHROMA_URL = process.env.CHROMA_URL;
const CHROMA_PATH = process.env.CHROMA_PATH;
const CHROMA_COLLECTION_PREFIX = process.env.CHROMA_COLLECTION_PREFIX || "futureyou";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

type MemoryType = "brief" | "debrief" | "nudge" | "chat" | "habit" | "reflection";

interface StoreMemoryParams {
  userId: string;
  type: MemoryType;
  text: string;
  metadata?: Record<string, any>;
  importance?: number; // 1-5
}

interface QueryMemoriesParams {
  userId: string;
  type?: string;
  query: string;
  limit?: number;
  minScore?: number;
}

interface Memory {
  text: string;
  score: number;
  metadata?: any;
}

export class SemanticMemoryService {
  private client: ChromaClient | null = null;
  private embedder: OpenAIEmbeddingFunction | null = null;
  private isAvailable: boolean = false;
  private initPromise: Promise<void> | null = null;

  constructor() {
    this.initPromise = this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      // DETAILED DIAGNOSTICS
      console.log("🔍 [Chroma Init] Starting initialization...");
      console.log(`🔍 [Chroma Init] CHROMA_URL: ${CHROMA_URL ? `"${CHROMA_URL}"` : "NOT SET"}`);
      console.log(`🔍 [Chroma Init] CHROMA_PATH: ${CHROMA_PATH ? `"${CHROMA_PATH}"` : "NOT SET"}`);
      console.log(`🔍 [Chroma Init] OPENAI_API_KEY: ${OPENAI_API_KEY ? "SET" : "NOT SET"}`);
      
      // Check if Chroma is configured
      if (!CHROMA_URL && !CHROMA_PATH) {
        console.warn("⚠️ Chroma not configured (no CHROMA_URL or CHROMA_PATH) — semantic memory disabled");
        this.isAvailable = false;
        return;
      }

      if (!OPENAI_API_KEY) {
        console.warn("⚠️ OPENAI_API_KEY missing — semantic memory disabled");
        this.isAvailable = false;
        return;
      }

      // Initialize Chroma client
      if (CHROMA_URL) {
        console.log(`🔗 Connecting to Chroma server at ${CHROMA_URL}...`);
        this.client = new ChromaClient({ path: CHROMA_URL });
      } else if (CHROMA_PATH) {
        console.log(`💾 Using local Chroma at ${CHROMA_PATH}...`);
        this.client = new ChromaClient({ path: CHROMA_PATH });
      }

      // Initialize OpenAI embedder
      console.log(`🔍 [Chroma Init] Creating OpenAI embedder...`);
      this.embedder = new OpenAIEmbeddingFunction({
        openai_api_key: OPENAI_API_KEY,
        openai_model: "text-embedding-3-small",
      });

      // Test connection
      console.log(`🔍 [Chroma Init] Testing connection with heartbeat...`);
      await this.client!.heartbeat();
      
      this.isAvailable = true;
      console.log("✅ Semantic memory initialized successfully");
    } catch (err: any) {
      console.error("❌ [Chroma Init] FAILED TO INITIALIZE:");
      console.error(`   Error type: ${err?.constructor?.name}`);
      console.error(`   Error message: ${err?.message}`);
      console.error(`   Error code: ${err?.code}`);
      console.error(`   Full error:`, err);
      console.warn("⚠️ Semantic memory disabled due to initialization failure");
      this.isAvailable = false;
      this.client = null;
      this.embedder = null;
    }
  }

  /**
   * Store a memory with vector embedding
   */
  async storeMemory(params: StoreMemoryParams): Promise<void> {
    await this.initPromise;

    if (!this.isAvailable || !this.client || !this.embedder) {
      console.debug(`[SemanticMemory] Skipping store (disabled) — ${params.type}`);
      return;
    }

    try {
      const collectionName = `${CHROMA_COLLECTION_PREFIX}_${params.userId.substring(0, 8)}`;
      
      // Get or create collection
      let collection;
      try {
        collection = await this.client.getOrCreateCollection({
          name: collectionName,
          embeddingFunction: this.embedder,
        });
      } catch (err) {
        console.warn(`⚠️ Failed to get/create collection ${collectionName}:`, err);
        return;
      }

      // Prepare metadata - ChromaDB only accepts flat string/number/boolean values
      const rawMetadata = {
        type: params.type,
        importance: params.importance || 3,
        timestamp: new Date().toISOString(),
        ...(params.metadata || {}),
      };

      // Sanitize metadata to ensure ChromaDB compatibility
      const metadata: Record<string, string | number | boolean> = {};
      for (const [key, value] of Object.entries(rawMetadata)) {
        if (value === null || value === undefined) {
          continue; // Skip null/undefined
        }
        if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
          metadata[key] = value;
        } else if (typeof value === 'object') {
          // Serialize objects/arrays as JSON strings
          metadata[key] = JSON.stringify(value);
        } else {
          // Convert other types to string
          metadata[key] = String(value);
        }
      }

      // Generate a unique ID
      const id = `${params.type}_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      // Add to collection
      await collection.add({
        ids: [id],
        documents: [params.text],
        metadatas: [metadata],
      });

      console.log(`📌 CHROMA UPSERT - Stored ${params.type} memory for user ${params.userId.substring(0, 8)}`);
      console.log(`   Collection: ${collectionName}`);
      console.log(`   Text preview: "${params.text.substring(0, 80)}..."`);
      console.log(`   Metadata: ${JSON.stringify(metadata)}`);
    } catch (err) {
      console.warn(`⚠️ Failed to store semantic memory:`, err);
    }
  }

  /**
   * Query memories by semantic similarity
   */
  async queryMemories(params: QueryMemoriesParams): Promise<Memory[]> {
    await this.initPromise;

    if (!this.isAvailable || !this.client || !this.embedder) {
      console.debug(`[SemanticMemory] Skipping query (disabled)`);
      return [];
    }

    try {
      const collectionName = `${CHROMA_COLLECTION_PREFIX}_${params.userId.substring(0, 8)}`;
      
      // Get collection
      let collection;
      try {
        collection = await this.client.getCollection({
          name: collectionName,
          embeddingFunction: this.embedder,
        });
      } catch (err) {
        console.debug(`[SemanticMemory] Collection ${collectionName} not found`);
        return [];
      }

      // Build where filter if type is specified
      const where = params.type ? { type: params.type } : undefined;

      // Query collection
      const results = await collection.query({
        queryTexts: [params.query],
        nResults: params.limit || 5,
        where,
      });

      // Parse results
      const memories: Memory[] = [];
      const documents = results.documents[0] || [];
      const metadatas = results.metadatas[0] || [];
      const distances = results.distances?.[0] || [];

      for (let i = 0; i < documents.length; i++) {
        const distance = distances[i] || 0;
        const score = 1 - distance; // Convert distance to similarity score

        // Filter by minimum score if specified
        if (params.minScore && score < params.minScore) {
          continue;
        }

        memories.push({
          text: documents[i] as string,
          score,
          metadata: metadatas[i],
        });
      }

      console.log(`🔎 CHROMA QUERY got: ${memories.length} memories for user ${params.userId.substring(0, 8)}`);
      console.log(`   Query: "${params.query.substring(0, 80)}..."`);
      console.log(`   Type filter: ${params.type || 'all'}`);
      console.log(`   Results preview: ${memories.slice(0, 2).map(m => `"${m.text.substring(0, 50)}..." (score: ${m.score.toFixed(2)})`).join(', ')}`);
      return memories;
    } catch (err) {
      console.warn(`⚠️ Failed to query semantic memories:`, err);
      return [];
    }
  }

  /**
   * Get recent memories without semantic search
   */
  async getRecentMemories(params: {
    userId: string;
    type?: string;
    limit?: number;
  }): Promise<Memory[]> {
    await this.initPromise;

    if (!this.isAvailable || !this.client || !this.embedder) {
      console.debug(`[SemanticMemory] Skipping getRecent (disabled)`);
      return [];
    }

    try {
      const collectionName = `${CHROMA_COLLECTION_PREFIX}_${params.userId.substring(0, 8)}`;
      
      // Get collection
      let collection;
      try {
        collection = await this.client.getCollection({
          name: collectionName,
          embeddingFunction: this.embedder,
        });
      } catch (err) {
        console.debug(`[SemanticMemory] Collection ${collectionName} not found`);
        return [];
      }

      // Build where filter if type is specified
      const where = params.type ? { type: params.type } : undefined;

      // Get recent items
      const results = await collection.get({
        where,
        limit: params.limit || 15,
      });

      // Parse results
      const memories: Memory[] = [];
      const documents = results.documents || [];
      const metadatas = results.metadatas || [];

      for (let i = 0; i < documents.length; i++) {
        memories.push({
          text: documents[i] as string,
          score: 1.0, // No semantic scoring for recent fetch
          metadata: metadatas[i],
        });
      }

      // Sort by timestamp descending
      memories.sort((a, b) => {
        const timeA = new Date(a.metadata?.timestamp || 0).getTime();
        const timeB = new Date(b.metadata?.timestamp || 0).getTime();
        return timeB - timeA;
      });

      console.log(`✅ [SemanticMemory] Retrieved ${memories.length} recent memories for user ${params.userId.substring(0, 8)}`);
      return memories;
    } catch (err) {
      console.warn(`⚠️ Failed to get recent memories:`, err);
      return [];
    }
  }

  /**
   * Check if semantic memory is available
   */
  isEnabled(): boolean {
    return this.isAvailable;
  }
}

// Singleton instance
export const semanticMemory = new SemanticMemoryService();

