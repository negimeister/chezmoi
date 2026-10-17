#!/bin/bash
for dir in verifier config check delivery transformation; do
cd ~/cov/$dir
if [[ "$(pwd)" == *"verifier"* ]]; then
  git checkout master
else
  git checkout main
fi
git pull
git tagpush "$1"
done
