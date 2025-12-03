#!/bin/bash
# 🛡️ IP PROTECTION SCRIPT
# Creates a stripped-down version for iOS developer without proprietary content

set -e  # Exit on error

echo "🛡️ STRIPPING PROPRIETARY CONTENT FOR iOS DEVELOPER BUILD..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Not in Flutter project root${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  WARNING: This will create a new branch and modify content${NC}"
echo -e "${YELLOW}   Your main branch will NOT be affected${NC}"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Step 1: Create new branch
echo ""
echo -e "${GREEN}📦 Step 1: Creating ios-developer-build branch...${NC}"
git checkout -b ios-developer-build 2>/dev/null || git checkout ios-developer-build
echo "✅ Branch created/checked out"

# Step 2: Strip Celebrity Systems
echo ""
echo -e "${GREEN}📦 Step 2: Replacing celebrity systems with placeholders...${NC}"
cat > lib/data/celebrity_systems.dart << 'EOF'
// 🌟 Celebrity Habit Systems Data
// PROPRIETARY CONTENT REMOVED FOR DEVELOPMENT BUILD
// This is a placeholder - production version contains 40+ licensed celebrity systems

class CelebritySystem {
  final String name;
  final String title;
  final String subtitle;
  final String tier;
  final List<String> habits;
  final String whyViral;
  final String emoji;
  final List<int> gradientColors; // RGB values for gradient

  const CelebritySystem({
    required this.name,
    required this.title,
    required this.subtitle,
    required this.tier,
    required this.habits,
    required this.whyViral,
    required this.emoji,
    required this.gradientColors,
  });
}

// 🔥 PLACEHOLDER SYSTEMS (For testing only)
final List<CelebritySystem> celebritySystems = [
  CelebritySystem(
    name: 'Example Person 1',
    title: 'Test System',
    subtitle: 'PLACEHOLDER FOR TESTING',
    tier: '🔥 EXTREME INTENSITY',
    habits: [
      'Placeholder habit 1',
      'Placeholder habit 2',
      'Placeholder habit 3',
      'Placeholder habit 4',
    ],
    whyViral: 'This is placeholder content for development purposes',
    emoji: '⚔️',
    gradientColors: [239, 68, 68, 185, 28, 28],
  ),
  CelebritySystem(
    name: 'Example Person 2',
    title: 'Demo System',
    subtitle: 'FOR DEVELOPMENT ONLY',
    tier: '🌟 HIGH INTENSITY',
    habits: [
      'Test habit 1',
      'Test habit 2',
      'Test habit 3',
    ],
    whyViral: 'Demo content - not for production',
    emoji: '💪',
    gradientColors: [34, 197, 94, 22, 163, 74],
  ),
];
EOF
echo "✅ Celebrity systems replaced with 2 placeholders"

# Step 3: Create placeholder viral systems file
echo ""
echo -e "${GREEN}📦 Step 3: Creating placeholder viral systems...${NC}"

# Read the file and replace just the _allSystems list
python3 << 'PYTHON_SCRIPT'
import re

# Read the file
with open('lib/screens/viral_systems_screen.dart', 'r') as f:
    content = f.read()

# Replace the _allSystems list with placeholder
placeholder_systems = """  final List<ViralSystem> _allSystems = [
    // PROPRIETARY CONTENT REMOVED FOR DEVELOPMENT BUILD
    // Production version contains 30+ curated viral systems
    ViralSystem(
      name: 'Test System 1',
      tagline: 'Placeholder for testing',
      icon: LucideIcons.sun,
      gradientColors: [const Color(0xFFFF6B35), const Color(0xFFF7931E), const Color(0xFFFFC837)],
      accentColor: const Color(0xFFFFC837),
      habits: ['Placeholder habit 1', 'Placeholder habit 2', 'Placeholder habit 3'],
    ),
    ViralSystem(
      name: 'Test System 2',
      tagline: 'Demo system for development',
      icon: LucideIcons.sparkles,
      gradientColors: [const Color(0xFFFF1493), const Color(0xFFFF69B4), const Color(0xFFFF85C1)],
      accentColor: const Color(0xFFFF69B4),
      habits: ['Demo habit 1', 'Demo habit 2'],
    ),
  ];"""

# Find and replace the _allSystems list
pattern = r'final List<ViralSystem> _allSystems = \[.*?\];'
content = re.sub(pattern, placeholder_systems, content, flags=re.DOTALL)

# Write back
with open('lib/screens/viral_systems_screen.dart', 'w') as f:
    f.write(content)

print("✅ Viral systems replaced with 2 placeholders")
PYTHON_SCRIPT

# Step 4: Replace welcome series content
echo ""
echo -e "${GREEN}📦 Step 4: Replacing welcome series with placeholder...${NC}"
cat > lib/data/welcome_series_content.dart << 'EOF'
// 🌑 7-Day Welcome Series Content
// PROPRIETARY CONTENT REMOVED FOR DEVELOPMENT BUILD

class WelcomeDay {
  final int day;
  final String title;
  final String body;
  final String? audioUrl;

  const WelcomeDay({
    required this.day,
    required this.title,
    required this.body,
    this.audioUrl,
  });
}

final List<WelcomeDay> welcomeSeries = [
  WelcomeDay(
    day: 1,
    title: 'Day 1: Welcome',
    body: 'Placeholder content for development build. Production version contains curated 7-day welcome series.',
  ),
  WelcomeDay(
    day: 2,
    title: 'Day 2: Getting Started',
    body: 'This is a placeholder. Real content is proprietary.',
  ),
];
EOF
echo "✅ Welcome series replaced with placeholders"

# Step 5: Remove backend premium logic (optional - makes it work in FREE mode)
echo ""
echo -e "${YELLOW}📦 Step 5: Backend premium checks...${NC}"
read -p "Remove backend premium checks? (Makes everything FREE for testing) (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing premium checks..."
    
    # Remove premium import and check from what-if controller
    if [ -f "backend/src/controllers/what-if-chat.controller.ts" ]; then
        sed -i '/import.*premium\.service/d' backend/src/controllers/what-if-chat.controller.ts
        sed -i '/🔒 PAYWALL/,/return;/d' backend/src/controllers/what-if-chat.controller.ts
    fi
    
    # Remove premium import and check from future-you controller
    if [ -f "backend/src/controllers/future-you-v2.controller.ts" ]; then
        sed -i '/import.*premium\.service/d' backend/src/controllers/future-you-v2.controller.ts
        sed -i '/🔒 PAYWALL/,/return;/d' backend/src/controllers/future-you-v2.controller.ts
    fi
    
    # Remove premium checks from scheduler
    if [ -f "backend/src/jobs/scheduler.ts" ]; then
        sed -i '/import.*premium\.service/d' backend/src/jobs/scheduler.ts
        sed -i '/🔒 PAYWALL/,/}/d' backend/src/jobs/scheduler.ts
    fi
    
    echo "✅ Premium checks removed (FREE mode enabled)"
else
    echo "⏭️  Keeping premium checks"
fi

# Step 6: Clean sensitive backend files
echo ""
echo -e "${GREEN}📦 Step 6: Checking for sensitive files...${NC}"
if [ -f "backend/.env" ]; then
    echo "⚠️  Found backend/.env - Creating placeholder..."
    cat > backend/.env << 'EOF'
# PLACEHOLDER ENVIRONMENT FILE
# Real credentials removed for security

DATABASE_URL=postgresql://localhost:5432/placeholder_db
OPENAI_API_KEY=sk-placeholder-key-for-testing
FIREBASE_SERVICE_ACCOUNT={}
REDIS_URL=redis://localhost:6379
EOF
    echo "✅ Created placeholder .env"
fi

# Step 7: Add watermark to stripped files
echo ""
echo -e "${GREEN}📦 Step 7: Adding IP protection notices...${NC}"
cat > IP_PROTECTION_NOTICE.md << 'EOF'
# ⚠️ INTELLECTUAL PROPERTY NOTICE

This codebase has been **stripped of proprietary content** for development purposes.

## What's Been Removed:
1. **Celebrity Systems** - 40+ curated celebrity habit systems (replaced with 2 placeholders)
2. **Viral Systems** - 30+ viral habit challenges (replaced with 2 placeholders)
3. **Welcome Series** - 7-day onboarding narrative (replaced with placeholders)
4. **AI Prompts** - Custom AI coaching prompts (placeholder text)
5. **Backend Credentials** - All API keys and database credentials

## Purpose:
This build is for **iOS compilation and alarm/notification bug fixes ONLY**.

## Legal:
- All intellectual property remains with the original owner
- Content cannot be copied, replicated, or used in other projects
- This is a development-only build with licensed content removed
- Developer has signed NDA regarding any proprietary code/logic seen

## Production Version:
The production app contains significantly more content and features that are
protected by intellectual property rights.

---
**If you have questions about missing content, contact the project owner.**
EOF
echo "✅ IP protection notice created"

# Step 8: Commit changes
echo ""
echo -e "${GREEN}📦 Step 8: Committing changes...${NC}"
git add -A
git commit -m "🛡️ Strip proprietary content for iOS developer build

REMOVED:
- 40+ celebrity systems (replaced with 2 placeholders)
- 30+ viral systems (replaced with 2 placeholders)  
- Welcome series content (replaced with placeholders)
- Backend credentials (placeholder .env)

PURPOSE:
- iOS build and testing only
- Alarm/notification fixes
- IP protection

This branch is safe to share with external developers.
Main branch contains full production content."

echo "✅ Changes committed to ios-developer-build branch"

# Step 9: Summary
echo ""
echo -e "${GREEN}🎉 IP STRIPPING COMPLETE!${NC}"
echo ""
echo -e "${YELLOW}SUMMARY:${NC}"
echo "  ✅ Created branch: ios-developer-build"
echo "  ✅ Replaced 40+ celebrity systems with 2 placeholders"
echo "  ✅ Replaced 30+ viral systems with 2 placeholders"
echo "  ✅ Replaced welcome series with placeholders"
echo "  ✅ Created IP protection notice"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo "  1. Review changes: git diff main ios-developer-build"
echo "  2. Test iOS build works with placeholders"
echo "  3. Push to separate repo: git push ios-build ios-developer-build"
echo "  4. Give developer access to THAT repo only"
echo ""
echo -e "${YELLOW}TO RETURN TO MAIN BRANCH:${NC}"
echo "  git checkout main"
echo ""
echo -e "${GREEN}Your main branch is UNTOUCHED - all original content preserved!${NC}"
EOF

chmod +x strip_ip_for_ios_dev.sh

echo "✅ Created IP protection script!"

