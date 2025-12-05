#!/bin/bash

# Script to push workflows to GitHub manually
echo "🔄 Pushing workflows to GitHub..."

# Try to push normally first
if git push origin main; then
    echo "✅ Workflows pushed successfully!"
else
    echo "⚠️ Normal push failed, trying alternative method..."
    
    # If that fails, we'll need to handle it differently
    echo "❌ GitHub token doesn't have workflow scope"
    echo "📝 Manual steps needed:"
    echo "1. Go to: https://github.com/seekumimi-dotcom/Futureyou-.git"
    echo "2. Create .github/workflows/ directory"
    echo "3. Add the 3 workflow files manually"
    echo ""
    echo "Or update your GitHub token with 'workflow' scope"
fi
