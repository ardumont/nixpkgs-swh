#!/usr/bin/env nix-shell
#!nix-shell -i bash
#!nix-shell -I nixpkgs=./nix
#!nix-shell -p nix git openssh python3
#!nix-shell --pure
set -euo pipefail

# TODO: get certs from nixpkgs.cacert instead or propagate some
# environment variable from the agent environment to the pipeline
# context?
export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

echo "#################################################"
echo "Cloning github.com/NixOS/nixpkgs-channels.git ..."
dir=nixpkgs-channels
if ! [[ -e $dir ]]; then
  git clone git://github.com/NixOS/nixpkgs-channels.git $dir
fi

git -C $dir remote update origin
git -C $dir checkout origin/nixos-19.09

# TODO: exit if the commit has been already built
COMMIT_ID=$(git -C $dir rev-parse HEAD)


echo "#################################################"
echo "Generating sources.json for commit $COMMIT_ID ..."
NIX_PATH=nixpkgs=$dir GC_INITIAL_HEAP_SIZE=4g nix-instantiate --strict --eval --json ./scripts/swh-urls.nix --argstr revision $COMMIT_ID > sources.json

echo "#################################################"
echo "Analyzing sources.json file and generating the README ..."
python ./scripts/analyze.py sources.json > README.md


echo "#################################################"
echo "Deploying to GitHub Pages..."

# Clean up the previous build dir :/
rm -rf nixpkgs-swh-gh-pages
mkdir nixpkgs-swh-gh-pages
cd nixpkgs-swh-gh-pages

export REMOTE_REPO="git@github.com:nix-community/nixpkgs-swh.git"

mv ../sources.json ../README.md .

git init
git config user.name "buildkite"
git config user.email "buildkite@none"
git add sources.json README.md
git commit -m 'Deploy to GitHub Pages'
# FIXME: the key location has to be updated
GIT_SSH_COMMAND='ssh -i /run/keys/github-nixpkgs-swh-key' git push --force $REMOTE_REPO master:gh-pages
