#!/bin/bash
# Security Verification Script
# Run this script to verify no credentials are exposed in your codebase

echo "🔍 Checking for exposed credentials in tracked files..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

has_issues=false

# Check for API keys in tracked files (excluding .env files)
echo "Checking for API keys in code files..."
if git ls-files | grep -v "\.env" | xargs grep -l "AIzaSy" 2>/dev/null; then
    echo -e "${RED}❌ WARNING: Found API keys in tracked files!${NC}"
    has_issues=true
else
    echo -e "${GREEN}✅ No API keys found in tracked code files${NC}"
fi

echo ""
echo "Checking for hardcoded tokens..."
if git ls-files | grep -v "\.env" | xargs grep -l "007eJx" 2>/dev/null; then
    echo -e "${RED}❌ WARNING: Found tokens in tracked files!${NC}"
    has_issues=true
else
    echo -e "${GREEN}✅ No tokens found in tracked code files${NC}"
fi

echo ""
echo "Checking if .env is ignored..."
if git check-ignore .env > /dev/null 2>&1; then
    echo -e "${GREEN}✅ .env file is properly ignored${NC}"
else
    echo -e "${RED}❌ WARNING: .env file is NOT ignored!${NC}"
    has_issues=true
fi

echo ""
echo "Checking if google-services.json is ignored..."
if git check-ignore android/app/google-services.json > /dev/null 2>&1; then
    echo -e "${GREEN}✅ google-services.json is properly ignored${NC}"
else
    echo -e "${YELLOW}⚠️  google-services.json might not be ignored${NC}"
fi

echo ""
echo "Verifying .env file exists..."
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
else
    echo -e "${RED}❌ .env file not found! Copy from .env.example${NC}"
    has_issues=true
fi

echo ""
echo "Verifying backend .env file exists..."
if [ -f "backend/.env" ]; then
    echo -e "${GREEN}✅ backend/.env file exists${NC}"
else
    echo -e "${YELLOW}⚠️  backend/.env file not found (optional)${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
if [ "$has_issues" = true ]; then
    echo -e "${RED}❌ SECURITY ISSUES FOUND! Please fix them before committing.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All security checks passed! Safe to commit.${NC}"
    exit 0
fi
