# 🔑 Get Railway DATABASE_URL

## Step 1: Get DATABASE_URL from Railway

1. Go to https://railway.app/dashboard
2. Click on your `futureyou` project
3. Click on the **PostgreSQL** service (the database icon)
4. Click the **"Variables"** tab
5. Find **DATABASE_URL**
6. Click the **"Copy"** button (or select and copy the entire URL)

It should look like:
```
postgresql://postgres:PASSWORD@monorail.proxy.rlwy.net:12345/railway
```

---

## Step 2: Run Migrations Locally

Open your terminal and run:

```bash
cd /home/felix/futureyou/backend

# Paste your DATABASE_URL here:
export DATABASE_URL="postgresql://postgres:PASSWORD@monorail.proxy.rlwy.net:12345/railway"

# Run migrations
npx prisma migrate deploy

# Generate Prisma client
npx prisma generate
```

That's it! This will create all tables in your Railway database.

---

## Step 3: Verify It Worked

```bash
# Test the database
npx prisma db execute --stdin <<< "SELECT count(*) FROM \"User\";"
```

Should show: `0` (zero users, but table exists!)

---

## Step 4: Test User Creation

```bash
curl -X POST https://futureyou-production.up.railway.app/api/v1/users \
  -H "Content-Type: application/json" \
  -H "x-user-id: test123" \
  -d '{}'
```

Should return user JSON! ✅

---

## Step 5: Restart Flutter App

```bash
cd /home/felix/futureyou
flutter run -d chrome
```

Chat should work now! 🎉

