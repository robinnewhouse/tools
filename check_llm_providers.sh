#!/usr/bin/env bash
# Check LLM provider API connectivity
# Usage: ./check_llm_providers.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Load environment variables from global .env
ENV_FILE="$HOME/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${RED}Error: $ENV_FILE not found${NC}"
    exit 1
fi

echo "Checking LLM provider connectivity..."
echo "======================================="
echo ""

# Store results in simple variables
result_anthropic=""
result_openai=""
result_gemini=""
result_openrouter=""
result_vercel=""
result_qwen=""

check_anthropic() {
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        result_anthropic="MISSING_KEY"
        return
    fi
    
    # Use models endpoint for a lightweight auth check
    response=$(curl -s -w "\n%{http_code}" -X GET "https://api.anthropic.com/v1/models" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
        result_anthropic="OK"
    elif [[ "$http_code" == "401" ]]; then
        result_anthropic="AUTH_FAILED"
    else
        result_anthropic="ERROR_$http_code"
    fi
}

check_openai() {
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
        result_openai="MISSING_KEY"
        return
    fi
    
    response=$(curl -s -w "\n%{http_code}" -X GET "https://api.openai.com/v1/models" \
        -H "Authorization: Bearer $OPENAI_API_KEY" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
        result_openai="OK"
    elif [[ "$http_code" == "401" ]]; then
        result_openai="AUTH_FAILED"
    else
        result_openai="ERROR_$http_code"
    fi
}

check_gemini() {
    if [[ -z "${GEMINI_API_KEY:-}" && -z "${GOOGLE_API_KEY:-}" ]]; then
        result_gemini="MISSING_KEY"
        return
    fi
    
    api_key="${GEMINI_API_KEY:-$GOOGLE_API_KEY}"
    response=$(curl -s -w "\n%{http_code}" \
        "https://generativelanguage.googleapis.com/v1/models?key=$api_key" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
        result_gemini="OK"
    elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
        result_gemini="AUTH_FAILED"
    else
        result_gemini="ERROR_$http_code"
    fi
}

check_openrouter() {
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        result_openrouter="MISSING_KEY"
        return
    fi
    
    response=$(curl -s -w "\n%{http_code}" -X GET "https://openrouter.ai/api/v1/auth/key" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
        result_openrouter="OK"
    elif [[ "$http_code" == "401" ]]; then
        result_openrouter="AUTH_FAILED"
    else
        result_openrouter="ERROR_$http_code"
    fi
}

check_vercel() {
    if [[ -z "${VERCEL_API_KEY:-}" && -z "${VERCEL_TOKEN:-}" ]]; then
        result_vercel="MISSING_KEY"
        return
    fi
    
    api_key="${VERCEL_API_KEY:-$VERCEL_TOKEN}"
    response=$(curl -s -w "\n%{http_code}" -X GET "https://api.vercel.com/v2/user" \
        -H "Authorization: Bearer $api_key" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
        result_vercel="OK"
    elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
        result_vercel="AUTH_FAILED"
    else
        result_vercel="ERROR_$http_code"
    fi
}

check_qwen() {
    # Qwen uses Alibaba Cloud's DashScope API
    if [[ -z "${DASHSCOPE_API_KEY:-}" && -z "${QWEN_API_KEY:-}" ]]; then
        result_qwen="MISSING_KEY"
        return
    fi
    
    api_key="${DASHSCOPE_API_KEY:-$QWEN_API_KEY}"
    response=$(curl -s -w "\n%{http_code}" -X POST "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d '{"model":"qwen-turbo","input":{"prompt":"hi"},"parameters":{"max_tokens":1}}' 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    if [[ "$http_code" == "200" ]]; then
        result_qwen="OK"
    elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
        result_qwen="AUTH_FAILED"
    else
        result_qwen="ERROR_$http_code"
    fi
}

print_result() {
    local provider="$1"
    local status="$2"
    case "$status" in
        "OK")
            echo -e "${GREEN}✓${NC} $provider: Connected"
            ;;
        "MISSING_KEY")
            echo -e "${YELLOW}○${NC} $provider: No API key configured"
            ;;
        "AUTH_FAILED")
            echo -e "${RED}✗${NC} $provider: Authentication failed (invalid key)"
            ;;
        *)
            echo -e "${RED}✗${NC} $provider: $status"
            ;;
    esac
}

# Run all checks
echo -n "Checking Anthropic... "
check_anthropic
echo "done"

echo -n "Checking OpenAI... "
check_openai
echo "done"

echo -n "Checking Gemini... "
check_gemini
echo "done"

echo -n "Checking OpenRouter... "
check_openrouter
echo "done"

echo -n "Checking Vercel... "
check_vercel
echo "done"

echo -n "Checking Qwen... "
check_qwen
echo "done"

echo ""
echo "Results"
echo "======================================="

print_result "Anthropic" "$result_anthropic"
print_result "OpenAI" "$result_openai"
print_result "Gemini" "$result_gemini"
print_result "OpenRouter" "$result_openrouter"
print_result "Vercel" "$result_vercel"
print_result "Qwen" "$result_qwen"
