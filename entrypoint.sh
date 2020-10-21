#!/bin/sh

set -e

if [[ $# -lt 1 ]]; then
    echo "Illegal number of parameters. Need at least source dir as first param"
    exit 2
fi

#TODO: Make these configurable
git_email="tools@mutoco.ch"
git_name="Builder"
source=$1

if [ ! -d "$source" ]; then
  echo "First parameter needs to be a directory"
  exit 2
fi

build_suffix=${2:--build}

if [ ! -z "$3" ]; then
  api_endpoint="https://api.github.com/orgs/$3/repos"
else
  api_endpoint="https://api.github.com/user/repos"
fi

branch=${GITHUB_REF##*/}
build_repo="${GITHUB_REPOSITORY}${build_suffix}"

status=$(curl -sI GET -u "${GITHUB_API_USERNAME}:${GITHUB_API_ACCESS_TOKEN}" "https://api.github.com/repos/$build_repo" 2>/dev/null | head -n 1 | cut -d$' ' -f2)
if [ $status = "404" ]; then
    echo "Build repository does not exist, creating new $build_repo"
    # let's first get info about current repository
    curl -s -X GET -u "${GITHUB_API_USERNAME}:${GITHUB_API_ACCESS_TOKEN}" "https://api.github.com/repos/${GITHUB_REPOSITORY}" | jq "{ private: .private, name: (.name + \"$build_suffix\"), description: (.name + \" (Build)\") }" > current-project.json
    # and from here we will create the new repository (same privacy, same type (scm), same project)
    curl -s -X POST -u "${GITHUB_API_USERNAME}:${GITHUB_API_ACCESS_TOKEN}" -H "Content-Type: application/json" -d @current-project.json "$api_endpoint" > new-project.json
    # Set the proper build-repo name from the API response
    build_repo=$(cat ./new-project.json | jq .full_name)
else
    echo "Found build repository $build_repo"
fi

if [ -z "$build_repo" ]; then
  echo "Build repository not available"
  exit 1
fi

repo_url="https://${GITHUB_API_USERNAME}:${GITHUB_API_ACCESS_TOKEN}@github.com/$build_repo.git"

dir=repo
git log --pretty=format:"%s" > $source/.gitlog

echo "Checking if branch $branch already exists ..."

mkdir $dir
cd $dir

if [[ `git ls-remote $repo_url refs/*/$branch` ]]; then
    echo "Branch $branch already exists, checking out."
    git clone --branch $branch --depth 25 $repo_url .
else
    echo "Branch name $branch doesn't exist yet - will create."
    git clone --depth 1 $repo_url .
    git checkout --orphan $branch
    git rm -rfq --ignore-unmatch .
fi

git config --global user.email $git_email
git config --global user.name $git_name
git config http.postBuffer 157286400

echo ".gitignore" >> ".rsync-exclude.txt"
echo ".git" >> ".rsync-exclude.txt"
rsync -ac ../$source/ . --delete --exclude-from='.rsync-exclude.txt'
#cat ".rsync-exclude.txt"
rm -f ".rsync-exclude.txt"

git add -u
git add -A .

# head will limit to max n number of lines
last_commit_messages="$(git diff --color=never --staged .gitlog | egrep "^\+[^\+]" | head -n20)"

if git diff-index --quiet HEAD --; then
    # no changes
    echo "No changes to previous build. Nothing to commit."
else
    git commit -a -m "Build ${GITHUB_RUN_NUMBER} -- $last_commit_messages"
    git push origin $branch
    echo "Pushed changes to build repository: Build ${GITHUB_RUN_NUMBER} -- $last_commit_messages"
fi

cd ..
rm -rf $dir
