# Chroma Connection Troubleshooting

## Common Issues

### 1. **Wrong URL Format**
```bash
# ❌ WRONG
CHROMA_URL=localhost:8000
CHROMA_URL=8000

# ✅ CORRECT
CHROMA_URL=http://localhost:8000
CHROMA_URL=https://your-chroma-instance.com
```

### 2. **Chroma Server Not Running**
```bash
# Check if Chroma is actually running
curl http://localhost:8000/api/v1/heartbeat

# If no response, Chroma server is not running
```

### 3. **Railway Environment Variable Not Loaded**
```bash
# Railway requires rebuild after env var changes
# Go to Railway dashboard → Settings → Variables → Add/Edit
# Then trigger a new deployment
```

### 4. **Network/Firewall Issues**
- If using Railway for Chroma, ensure it's on the same project
- If using external Chroma, ensure firewall allows connection
- Railway services can communicate via internal DNS

### 5. **chromadb NPM Package Issue**
```bash
# The chromadb client might have compatibility issues
# Check package.json version
```

## Quick Fix Options

### Option A: Use Hosted Chroma
```bash
# Sign up at: https://www.trychroma.com/
# Get your URL and set:
CHROMA_URL=https://api.trychroma.com
CHROMA_API_TOKEN=your_token_here  # if required
```

### Option B: Deploy Chroma on Railway
```bash
# Add new service in Railway
# Use Docker image: chromadb/chroma:latest
# Expose port 8000
# Set internal URL as CHROMA_URL
```

### Option C: Disable Chroma (Temporary)
```bash
# Remove CHROMA_URL and CHROMA_PATH from env vars
# System will work without semantic memory
# Reflections saved to Postgres only
```

## Next Steps

1. Deploy this code
2. Check Railway logs for the detailed error
3. Look for lines starting with "🔍 [Chroma Init]" and "❌ [Chroma Init]"
4. Share the exact error message

Common error messages:
- "ECONNREFUSED" → Chroma server not running / wrong URL
- "ETIMEDOUT" → Network/firewall issue
- "404 Not Found" → Wrong URL path
- "Unauthorized" → Missing auth token

