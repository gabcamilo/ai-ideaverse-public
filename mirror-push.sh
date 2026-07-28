#!/usr/bin/env bash
set -e
# chmod +x mirror-push.sh

unset GITHUB_TOKEN
gh auth login
gh auth setup-git
git push --mirror https://github.com/gabcamilo/ai-ideaverse-public.git
