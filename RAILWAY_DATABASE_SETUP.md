# 🚨 CRITICAL: Railway Database is Empty!

## Problem

Your backend code is deployed to Railway, but the **PostgreSQL database has no tables**!

Error: `The table 'public.User' does not exist`

## Solution: Run Prisma Migrations on Railway

### Method 1: Via Railway CLI (Recommended)

```bash
# Install Railway CLI (if not installed)
npm install -g @railway/cli

# Login to Railway
railway login

# Link to your project
cd /home/felix/futureyou/backend
railway link

# Run migrations
railway run npx prisma migrate deploy
```

### Method 2: Via Railway Dashboard

1. Go to https://railway.app/dashboard
2. Click on your `futureyou` project
3. Click on your **backend service** (not PostgreSQL)
4. Click **"Settings"** tab
5. Scroll to **"Deploy Triggers"**
6. Add a **"Build Command"**:
   ```bash
   npm install && npx prisma generate && npx prisma migrate deploy
   ```
7. Redeploy the service

### Method 3: Manually via Railway Console

1. Go to Railway dashboard
2. Click on your backend service
3. Click **"Deployments"** tab
4. Click on the latest deployment
5. Click **"View Logs"**
6. Click **"Shell"** button (terminal icon)
7. Run:
   ```bash
   cd /app
   npx prisma migrate deploy
   npx prisma generate
   ```

### Method 4: Run Locally (Connects to Railway DB)

If you have the Railway DATABASE_URL:

```bash
cd /home/felix/futureyou/backend

# Set DATABASE_URL from Railway
export DATABASE_URL="postgresql://postgres:password@host:port/database"

# Run migrations
npx prisma migrate deploy
```

**Get DATABASE_URL:**
1. Railway dashboard → PostgreSQL service → Variables tab → Copy DATABASE_URL

---

## Verify Database Setup

After running migrations, test:

```bash
# Test user creation
curl -X POST https://futureyou-production.up.railway.app/api/v1/users \
  -H "Content-Type: application/json" \
  -H "x-user-id: user_test_123" \
  -d '{}'
```

**Expected response:**
```json
{
  "user": {
    "id": "user_test_123",
    "email": "user_test_123@futureyou.app",
    "tz": "Europe/London",
    ...
  },
  "created": true
}
```

---

## What Tables Should Exist

After migrations, you should have:

- `User` - User profiles
- `Event` - All events (habits, completions, messages, system)
- `_prisma_migrations` - Migration history

---

## Quick Check

```bash
# Check if database is set up
curl https://futureyou-production.up.railway.app/health
```

Should return:
```json
{
  "ok": true,
  "uptime": 123.45,
  "timestamp": "..."
}
```

---

## After Database is Set Up

Then restart your Flutter app:

```bash
cd /home/felix/futureyou
flutter run -d chrome
```

You should see:
```
✅ User created on backend: user_1761700736030
✅ Synced 0 messages
```

Then chat will work! 🎉

