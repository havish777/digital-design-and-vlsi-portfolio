#!/bin/bash
# Run inside this folder after installing git + GitHub CLI and running: gh auth login
set -e
git init -b main
git add .
git commit -m "Initial commit: digital design and VLSI portfolio"
gh repo create digital-design-and-vlsi-portfolio --public --source=. --push
echo "Done. Repo URL:"; gh repo view --json url -q .url
