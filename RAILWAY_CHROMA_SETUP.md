# Deploy Chroma on Railway

## Step 1: Add Chroma Service to Your Railway Project

1. Go to your Railway project: https://railway.app/project/YOUR_PROJECT_ID
2. Click **"+ New"** → **"Empty Service"**
3. Name it: **"chroma"**

## Step 2: Deploy Chroma Docker Image

1. Click on the new "chroma" service
2. Go to **Settings** → **Source**
3. Select **"Deploy from Docker Image"**
4. Enter image: `chromadb/chroma:latest`

## Step 3: Configure Chroma Service

1. Go to **Settings** → **Networking**
2. Click **"Generate Domain"** (this creates a public URL)
3. Note the internal hostname (should be like `chroma.railway.internal`)

## Step 4: Set Environment Variable in Backend

1. Go to your **backend** service in Railway
2. Go to **Variables**
3. Add new variable:
   ```
   CHROMA_URL=http://chroma.railway.internal:8000
   ```
   (Use internal URL for faster, free traffic between services)

4. Click **"Add"** and Railway will auto-redeploy

## Step 5: Verify

Check your backend logs for:
```
🔍 [Chroma Init] CHROMA_URL: "http://chroma.railway.internal:8000"
🔍 [Chroma Init] Testing connection with heartbeat...
✅ Semantic memory initialized successfully
```

## Alternative: Use Public URL

If internal URL doesn't work, use the public URL:
```
CHROMA_URL=https://chroma-production-XXXX.up.railway.app
```

## What This Does

- Creates a persistent Chroma vector database
- Stores user reflections as embeddings
- Enables semantic memory search
- Allows AI to reference past conversations ("You told me last week...")

## Cost

- Chroma on Railway: ~$5-10/month (depends on usage)
- Or use Railway's free trial credits

