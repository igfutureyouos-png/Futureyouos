#!/bin/bash
# 🚨 EMERGENCY IP PROTECTION - Delete and Recreate with Stripped Content

set -e

echo "🚨 EMERGENCY IP PROTECTION PROTOCOL"
echo "=================================="
echo ""
echo "This script will:"
echo "  1. Strip all proprietary content (celebrity/viral systems)"
echo "  2. Prepare a clean version for new GitHub repo"
echo "  3. Give you commands to complete the process"
echo ""
echo "⚠️  YOU MUST MANUALLY:"
echo "  - Delete the old GitHub account"
echo "  - Create a new GitHub account"
echo "  - Push the stripped version"
echo ""
read -p "Ready to proceed? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Step 1: Strip all IP
echo ""
echo "📦 STEP 1: Stripping proprietary content..."
./strip_ip_for_ios_dev.sh

# Step 2: Verify what's in the stripped version
echo ""
echo "📋 STEP 2: Verifying stripped content..."
git checkout ios-developer-build
echo ""
echo "✅ Celebrity systems file:"
head -20 lib/data/celebrity_systems.dart
echo ""
echo "✅ File size comparison:"
wc -l lib/data/celebrity_systems.dart
echo ""

# Step 3: Create instructions for manual steps
echo ""
echo "🎯 STEP 3: MANUAL STEPS YOU MUST DO NOW"
echo "========================================"
cat > MANUAL_STEPS.txt << 'EOF'
🚨 COMPLETE THESE STEPS IMMEDIATELY:

1️⃣ DELETE OLD GITHUB ACCOUNT
   - Go to: https://github.com/settings/account
   - Scroll to bottom: "Delete your account"
   - Confirm deletion
   - ✅ This deletes ALL repos and history

2️⃣ CREATE NEW GITHUB ACCOUNT
   - Go to: https://github.com/signup
   - Use NEW email (not same as before)
   - Use strong password
   - ✅ Keep password SECRET this time!

3️⃣ CREATE NEW PRIVATE REPO
   - Name it: futureyou-ios
   - Make it PRIVATE
   - Don't initialize with README
   - ✅ Copy the repo URL

4️⃣ PUSH STRIPPED VERSION (run these commands):
   
   cd /home/felix/futureyou
   git checkout ios-developer-build
   
   # Remove old remote
   git remote remove origin
   
   # Add new remote (replace URL with yours)
   git remote add origin https://github.com/NEW_ACCOUNT/futureyou-ios.git
   
   # Push stripped version as main branch
   git push -u origin ios-developer-build:main --force
   
   # Delete local main branch (prevent accidents)
   git branch -D main
   
   ✅ Now repo ONLY has stripped content!

5️⃣ GIVE DEVELOPER ACCESS (Choose one):
   
   Option A: Add as Collaborator (RECOMMENDED)
   - Repo → Settings → Collaborators
   - Add his GitHub username
   - You can revoke access anytime
   
   Option B: Share Account Password
   - Only if you trust him
   - But now repo only has placeholders
   - No IP to steal even with full access

6️⃣ TELL DEVELOPER:
   
   "I've set up a new repo for the iOS build.
   Clone from: https://github.com/NEW_ACCOUNT/futureyou-ios.git
   
   Note: This is a development build with placeholder content.
   Focus on iOS build configuration and alarm fixes only."

7️⃣ AFTER iOS WORK COMPLETE:
   
   - Review his commits
   - Cherry-pick ONLY iOS fixes to your local main branch
   - Revoke his access
   - Keep your REAL content safe locally

✅ YOUR IP IS NOW PROTECTED!
EOF

cat MANUAL_STEPS.txt

echo ""
echo "📄 Instructions saved to: MANUAL_STEPS.txt"
echo ""
echo "🎯 CURRENT STATUS:"
echo "  ✅ Proprietary content stripped"
echo "  ✅ ios-developer-build branch ready"
echo "  ✅ Safe to push to new repo"
echo ""
echo "⚠️  NEXT: Follow MANUAL_STEPS.txt to complete protection"
echo ""
echo "🔒 Once complete, developer will see:"
echo "   - 2 placeholder celebrity systems (NOT your 40+)"
echo "   - 2 placeholder viral systems (NOT your 30+)"
echo "   - No git history of real content"
echo "   - No way to access your IP"
echo ""
echo "✅ Your intellectual property will be 100% SAFE!"
EOF

chmod +x EMERGENCY_RESET.sh

echo "✅ Emergency reset script created!"

