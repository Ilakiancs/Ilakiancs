#!/usr/bin/env bash
# Rewrites the "Lately" block in README.md with the most recently pushed public
# repositories, their latest release (if any) and description.
set -euo pipefail

USER_LOGIN="${USER_LOGIN:-Ilakiancs}"
LIMIT="${LIMIT:-5}"
README="${README:-README.md}"
SKIP='^(Ilakiancs|dotfiles)$'

rows=$(gh api graphql -F login="$USER_LOGIN" -f query='
  query($login: String!) {
    user(login: $login) {
      repositories(first: 30, privacy: PUBLIC, ownerAffiliations: OWNER, isFork: false,
                   orderBy: {field: PUSHED_AT, direction: DESC}) {
        nodes { name url description pushedAt latestRelease { tagName url } }
      }
    }
  }' --jq '.data.user.repositories.nodes[]' |
  jq -r --arg skip "$SKIP" '
    select(.name | test($skip) | not)
    | "| [**\(.name)**](\(.url)) | "
      + (if .latestRelease then "[`\(.latestRelease.tagName)`](\(.latestRelease.url))" else "–" end)
      + " | \((.description // "") | gsub("\\|"; "/") | if length > 90 then (.[0:90] | sub("[ ,.;:—-]+[^ ]*$"; "")) + "…" else . end) | "
      + (.pushedAt | fromdateiso8601 | strftime("%b %Y")) + " |"' |
  head -n "$LIMIT")

block=$(printf '%s\n%s\n%s' \
  '| Project | Release | What it is | Updated |' \
  '|:--|:--|:--|:--|' \
  "$rows")

BLOCK="$block" perl -0pi -e 's/(<!-- LATELY:START -->\n).*?(<!-- LATELY:END -->)/$1$ENV{BLOCK}\n$2/s' "$README"
