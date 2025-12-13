# Deploy Chroma Right Now - Step by Step

You just created service "grand-essance" - here's what to do next:

## Step 1: Deploy Chroma Docker Image

1. Click on **"grand-essance"** service in Railway
2. Go to **Settings** tab (left sidebar)
3. Scroll to **Source** section
4. Click **"Deploy from Docker Image"**
5. In the text box, enter exactly:
   ```
   chromadb/chroma:latest
   ```
6. Click **Save** or hit Enter
7. Railway will start deploying (watch the logs)

## Step 2: Expose Chroma with a Public URL

1. Still in "grand-essance" service
2. Go to **Settings** → **Networking** section
3. Click **"Generate Domain"**
4. Railway will give you a URL like:
   ```
   grand-essance-production-XXXX.up.railway.app
   ```
5. **Copy this URL** (you'll need it in next step)

## Step 3: Update Backend Environment Variable

1. Go back to your **backend** service (not grand-essance)
2. Click **Variables** tab
3. Find the variable `CHROMA_URL`
4. Change it from:
   ```
   http://chroma.railway.internal:8000
   ```
   to (using the URL from Step 2):
   ```
   https://grand-essance-production-XXXX.up.railway.app
   ```
5. Click **Save** or press Enter
6. Railway will auto-redeploy your backend

## Step 4: Verify It Worked

Watch your backend logs for:
```
🔍 [Chroma Init] CHROMA_URL: "https://grand-essance-production-XXXX.up.railway.app"
🔍 [Chroma Init] Testing connection with heartbeat...
✅ Semantic memory initialized successfully
```

If you see that ✅, YOU'RE DONE!

## Troubleshooting

If you see errors:
- Wait 1-2 minutes for Chroma to fully start
- Check "grand-essance" logs to make sure Chroma is running
- Look for "Server started" or similar in grand-essance logs

## What You Just Did

You now have:
- ✅ Chroma vector database running on Railway
- ✅ Backend connected to Chroma
- ✅ Full semantic memory enabled
- ✅ AI can reference past reflections

Cost: ~$5-10/month on Railway (or free with credits)

