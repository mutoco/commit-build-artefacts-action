#!/bin/sh

set -e

# Initialize variables from inputs
source_dir=${INPUT_SOURCE:-build}
source_path="$GITHUB_WORKSPACE/$source_dir"
#source_path="$(realpath $source)"
build_suffix=${INPUT_SUFFIX:--build}

# GITHUB_REF and GITHUB_REPOSITORY are part of the default ENV variables from Github
branch=${GITHUB_REF##*/}
build_repo="${GITHUB_REPOSITORY}${build_suffix}"

if [ ! -z "$INPUT_ORGANISATION" ]; then
  api_endpoint="https://api.github.com/orgs/$INPUT_ORGANISATION/repos"
else
  api_endpoint="https://api.github.com/user/repos"
fi


status=$(curl -sI GET -u "${API_USERNAME}:${API_ACCESS_TOKEN}" "https://api.github.com/repos/$build_repo" 2>/dev/null | head -n 1 | cut -d ' ' -f2)
if [ $status = "404" ]; then
    echo "Build repository does not exist, creating new $build_repo"
    # let's first get info about current repository
    curl -s -X GET -u "${API_USERNAME}:${API_ACCESS_TOKEN}" "https://api.github.com/repos/${GITHUB_REPOSITORY}" | jq "{ private: .private, name: (.name + \"$build_suffix\"), description: (.name + \" (Build)\") }" > current-project.json
    # and from here we will create the new repository (same privacy, same type (scm), same project)
    curl -s -X POST -u "${API_USERNAME}:${API_ACCESS_TOKEN}" -H "Content-Type: application/json" -d @current-project.json "$api_endpoint" > new-project.json
    # Set the proper build-repo name from the API response
    build_repo=$(cat ./new-project.json | jq .full_name)
else
    echo "Found build repository $build_repo"
fi

if [ -z "$build_repo" ]; then
  echo "Build repository not available"
  exit 1
fi

repo_url="https://${API_USERNAME}:${API_ACCESS_TOKEN}@github.com/$build_repo.git"

dir="$GITHUB_WORKSPACE/build-artefacts-tmp"
git log --pretty=format:"%s" > $source_path/.gitlog

echo "Checking if branch $branch already exists…"

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

git config http.postBuffer 157286400

echo ".gitignore" >> ".rsync-exclude.txt"
echo ".git" >> ".rsync-exclude.txt"

rsync -ac $source_path/ . --delete --exclude-from='.rsync-exclude.txt'
rm -f ".rsync-exclude.txt"

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
