# Backend Setup Guide

## Current Status

✅ **Frontend Complete** - All backend integration code is implemented  
⚠️ **Backend User Creation Required** - Users must exist in PostgreSQL database

## The Issue

The app is getting **HTTP 500 errors** because:
1. The backend expects users to exist in the PostgreSQL database
2. Currently there's no user auto-creation endpoint
3. The frontend generates a unique user ID but the backend doesn't recognize it

## Quick Fix Options

### Option 1: Run Backend Locally (Recommended for Development)

```bash
cd backend
npm install
# Set up .env file with:
# DATABASE_URL=your_postgres_url
# REDIS_URL=your_redis_url  
# OPENAI_API_KEY=your_key
npm run dev
```

Then update `lib/services/api_client.dart`:
```dart
static const String _baseUrl = 'http://localhost:8080';
```

### Option 2: Create User in Railway Database

1. Go to Railway dashboard
2. Open PostgreSQL database
3. Run SQL:
```sql
INSERT INTO "User" (id, email, tz, tone, intensity, "createdAt", "updatedAt")
VALUES ('user_1234567890', 'test@example.com', 'Europe/London', 'balanced', 2, NOW(), NOW());
```

4. Update `lib/services/api_client.dart`:
```dart
static String _userId = 'user_1234567890'; // Use the ID you created
```

### Option 3: Add User Creation Endpoint to Backend

Add to `backend/src/controllers/system.controller.ts`:
```typescript
fastify.post('/api/v1/users', async (req, reply) => {
  const { userId, email } = req.body as { userId: string; email?: string };
  
  const existing = await prisma.user.findUnique({ where: { id: userId } });
  if (existing) {
    return { user: existing, created: false };
  }
  
  const user = await prisma.user.create({
    data: {
      id: userId,
      email: email || `${userId}@temp.com`,
      tz: 'Europe/London',
      tone: 'balanced',
      intensity: 2,
    },
  });
  
  return { user, created: true };
});
```

Then call this in `lib/main.dart` during initialization.

## Current App Behavior

**Good News:** The app works perfectly **offline**!
- All local features work (habits, planner, mirror, streak)
- Data persists in Hive (local storage)
- UI is fully functional

**What Won't Work Until Backend is Fixed:**
- ❌ AI Chat responses
- ❌ Morning briefs / Evening debriefs
- ❌ Nudges from coach
- ❌ Message inbox sync

## Testing Offline Features

You can test everything except AI features:
1. ✅ Create habits
2. ✅ Mark completions
3. ✅ View streak
4. ✅ Use planner
5. ✅ Mirror reflections (local calculations)

## Next Steps

**For full functionality:**
1. Set up backend locally OR
2. Create users in Railway database OR  
3. Add user creation endpoint

**The frontend is 100% ready** - just waiting for backend user setup! 🚀

