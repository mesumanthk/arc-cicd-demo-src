#!/usr/bin/env bash

while getopts "s:d:r:b:i:t:e:p:" option;
    do
    case "$option" in
        s ) SOURCE_FOLDER=${OPTARG};;
        d ) DEST_FOLDER=${OPTARG};;
        r ) DEST_REPO=${OPTARG};;
        b ) DEST_BRANCH=${OPTARG};;
        i ) DEPLOY_ID=${OPTARG};;
        t ) TOKEN=${OPTARG};;
        e ) ENV_NAME=${OPTARG};;
    esac
done
echo "List input params"
echo $SOURCE_FOLDER
echo $DEST_FOLDER
echo $DEST_REPO
echo $DEST_BRANCH
echo $DEPLOY_ID
echo $ENV_NAME
echo $TOKEN
echo "end of list"

set -euo pipefail  # fail on error

pr_user_name="Git Ops"
pr_user_email="agent@gitops.com"

git config --global user.email $pr_user_email
git config --global user.name $pr_user_name

# Clone manifests repo
echo "Clone manifests repo"
repo_url="${DEST_REPO#http://}"
repo_url="${DEST_REPO#https://}"
repo_url="https://automated:$TOKEN@$repo_url"

echo "git clone $repo_url -b $DEST_BRANCH --depth 1 --single-branch"
git clone $repo_url -b $DEST_BRANCH --depth 1 --single-branch
repo=${DEST_REPO##*/}
repo_name=${repo%.*}
cd "$repo_name"
echo "git status"
git status

# Create a new branch 
deploy_branch_name=deploy/$DEPLOY_ID/$BACKEND_IMAGE/$DEST_BRANCH

echo "Create a new branch $deploy_branch_name"
git checkout -b $deploy_branch_name

# Add generated manifests to the new deploy branch
mkdir -p $DEST_FOLDER
cp -r $SOURCE_FOLDER/* $DEST_FOLDER/
git add -A
git status
if [[ `git status --porcelain | head -1` ]]; then
    git commit -m "deployment $DEPLOY_ID"

    # Push to the deploy branch 
    echo "Push to the deploy branch $deploy_branch_name"
    echo "git push --set-upstream $repo_url $deploy_branch_name"
    git push --set-upstream $repo_url $deploy_branch_name

    # Create a PR 
    echo "Create a PR to $DEST_BRANCH"
    
    owner_repo="${DEST_REPO#https://github.com/}"
    echo $owner_repo
    GITHUB_TOKEN=$TOKEN
    echo $GITHUB_TOKEN | gh auth login --with-token
    gh pr create --base $DEST_BRANCH --head $deploy_branch_name --title "deployment '$DEPLOY_ID'" --body "Deploy to '$ENV_NAME'"
fi 
