#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./gh_prs.sh [options]
# Options:
#   -r, --repo OWNER/REPO   Repository (default: cline/cline)
#   -a, --author USERNAME   GitHub username (default: robinnewhouse)
#   -s, --since DATE        Date in ISO format or relative (e.g., "7 days ago", "2024-01-01")
#                           Default: 7 days ago
#   -h, --help              Show this help message
#
# Examples:
#   ./gh_prs.sh
#   ./gh_prs.sh -r cline/cline -a robinnewhouse
#   ./gh_prs.sh --since "2024-01-01"
#   ./gh_prs.sh -s "14 days ago" -a myusername
#
# Requirements: gh (authenticated). Optional: jq.
# Note: "merged in the last week" uses merge date; "opened in the last week" uses created date.

# Defaults
REPO="cline/cline"
AUTHOR="robinnewhouse"
SINCE_INPUT=""

usage() {
  sed -n '3,15p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--repo)
      REPO="$2"
      shift 2
      ;;
    -a|--author)
      AUTHOR="$2"
      shift 2
      ;;
    -s|--since)
      SINCE_INPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Calculate SINCE date
if [[ -n "$SINCE_INPUT" ]]; then
  # Try to parse user-provided date
  if date -v -1d "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    # BSD date (macOS)
    if [[ "$SINCE_INPUT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
      # ISO date format - use directly
      SINCE="${SINCE_INPUT}T00:00:00Z"
    else
      # Relative date like "7 days ago" - BSD date doesn't support -d, parse manually
      if [[ "$SINCE_INPUT" =~ ^([0-9]+)[[:space:]]*(day|days)[[:space:]]*ago$ ]]; then
        days="${BASH_REMATCH[1]}"
        SINCE="$(date -u -v "-${days}d" "+%Y-%m-%dT%H:%M:%SZ")"
      else
        echo "Error: Unrecognized date format: $SINCE_INPUT" >&2
        echo "Use ISO format (YYYY-MM-DD) or 'N days ago'" >&2
        exit 1
      fi
    fi
  else
    # GNU date (Linux)
    if [[ "$SINCE_INPUT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
      SINCE="${SINCE_INPUT}T00:00:00Z"
    else
      SINCE="$(date -u -d "$SINCE_INPUT" "+%Y-%m-%dT%H:%M:%SZ")"
    fi
  fi
else
  # Default: 7 days ago
  if date -v -7d "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    SINCE="$(date -u -v -7d "+%Y-%m-%dT%H:%M:%SZ")"
  else
    SINCE="$(date -u -d "7 days ago" "+%Y-%m-%dT%H:%M:%SZ")"
  fi
fi

echo "Repo:   $REPO"
echo "User:   $AUTHOR"
echo "Since:  $SINCE"
echo

echo "=== Opened in last week ==="
if command -v jq >/dev/null 2>&1; then
  prs_opened_json=$(GH_PAGER=cat gh pr list --repo "$REPO" --author "$AUTHOR" --search "created:>=$SINCE" --state all --limit 200 \
    --json number,title,url,createdAt,state)

  echo "$prs_opened_json" | jq -r '.[] | "#\(.number)  \(.state)  \(.title)\n  \(.url)"'
else
  GH_PAGER=cat gh pr list --repo "$REPO" --author "$AUTHOR" --search "created:>=$SINCE" --state all --limit 200 \
    --json number,title,url,createdAt,state \
    --template '{{range .}}{{printf "#%-6v %-8v %s\n  %s\n" .number .state .title .url}}{{end}}'

  opened_numbers=$(GH_PAGER=cat gh pr list --repo "$REPO" --author "$AUTHOR" --search "created:>=$SINCE" --state all --limit 200 \
    --json number \
    --template '{{range .}}{{printf "%v\n" .number}}{{end}}')
fi

echo
echo "=== Merged in last week ==="
if command -v jq >/dev/null 2>&1; then
  prs_merged_json=$(GH_PAGER=cat gh pr list --repo "$REPO" --search "author:$AUTHOR is:pr is:merged merged:>=$SINCE" --limit 200 \
    --json number,title,url,mergedAt)

  echo "$prs_merged_json" | jq -r '.[] | "#\(.number)  merged  \(.title)\n  \(.url)"'
else
  GH_PAGER=cat gh pr list --repo "$REPO" --search "author:$AUTHOR is:pr is:merged merged:>=$SINCE" --limit 200 \
    --json number,title,url,mergedAt \
    --template '{{range .}}{{printf "#%-6v merged %s\n  %s\n" .number .title .url}}{{end}}'
fi

echo
echo "=== PR details ==="
if command -v jq >/dev/null 2>&1; then
  printf '%s\n%s\n' "$prs_opened_json" "$prs_merged_json" | jq -s 'add | .[].number' | sort -u | while read -r pr_number; do
    if [[ -n "$pr_number" ]]; then
      echo
      GH_PAGER=cat gh pr view "$pr_number" --repo "$REPO"
    fi
  done
else
  merged_numbers=$(GH_PAGER=cat gh pr list --repo "$REPO" --search "author:$AUTHOR is:pr is:merged merged:>=$SINCE" --limit 200 \
    --json number \
    --template '{{range .}}{{printf "%v\n" .number}}{{end}}')

  printf '%s\n%s\n' "$opened_numbers" "$merged_numbers" | sort -u | while read -r pr_number; do
    if [[ -n "$pr_number" ]]; then
      echo
      GH_PAGER=cat gh pr view "$pr_number" --repo "$REPO"
    fi
  done
fi
