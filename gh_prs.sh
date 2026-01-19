#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./my_prs_last_week.sh [owner/repo]
# Examples:
#   ./my_prs_last_week.sh
#   ./my_prs_last_week.sh cline/cline
#
# Requirements: gh (authenticated). Optional: jq.
# Note: "merged in the last week" uses merge date; "opened in the last week" uses created date.

REPO="${1:-cline/cline}"
AUTHOR="robinnewhouse"

# Works on GNU date (Linux) and BSD date (macOS)
if date -v -7d "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
  SINCE="$(date -u -v -7d "+%Y-%m-%dT%H:%M:%SZ")"
else
  SINCE="$(date -u -d "7 days ago" "+%Y-%m-%dT%H:%M:%SZ")"
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