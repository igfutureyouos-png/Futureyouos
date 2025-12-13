# Git Workflow Guide

This project uses a simplified Git workflow to make development easier.

## Quick Start

### 1. Simple Git Workflow (Recommended)

Use the provided script for easy commits and pushes:

```bash
# Make your changes to the code
# Then commit and push with a message
./git-workflow.sh "your commit message here"

# Or use the default message
./git-workflow.sh
```

### 2. Manual Git Commands

If you prefer manual control:

```bash
# Add all changes
git add -A

# Commit with a message
git commit -m "your commit message"

# Push to remote
git push
```

## Branch Strategy

- **main**: Production-ready code
- **develop**: Development branch for features
- **feature/***: Feature branches (optional)

## Commit Message Format

Use clear, descriptive commit messages:

```
feat: add new habit tracking feature
fix: resolve APK build error
docs: update README
style: improve code formatting
refactor: simplify git workflow
```

## GitHub Actions

The project automatically builds APK files when you push to main or develop branches:

1. **Debug APK**: Built on every push
2. **Release APK**: Built on every push
3. **Test Coverage**: Generated and uploaded

Download APK files from the Actions tab in GitHub.

## Troubleshooting

### Push Fails
- Check your internet connection
- Verify git credentials
- Run `git push` manually to see detailed errors

### No Remote Repository
If you get "No remote origin found":
```bash
git remote add origin https://github.com/yourusername/yourrepo.git
git push -u origin main
```

### Flutter Build Issues
- Ensure Flutter is installed and in PATH
- Run `flutter doctor` to check setup
- The GitHub Actions will handle builds automatically

## File Structure

- `git-workflow.sh`: Simple script for commits and pushes
- `.github/workflows/android-apk.yml`: Automated APK building
- `.gitignore`: Files to ignore in version control
- `GIT_WORKFLOW.md`: This guide