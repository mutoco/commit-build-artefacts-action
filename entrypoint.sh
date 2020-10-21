#!/bin/sh

set -e

if [[ $# -lt 1 ]]; then
    echo "Illegal number of parameters. Need at least source dir as first param"
    exit 2
fi

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
    printTitle "- Branch $branch already exists, checking out."
    git clone --branch $branch --depth 25 $repo_url .
else
    printTitle "- Branch name $branch doesn't exist yet - will create."
    git clone --depth 1 $repo_url .
    git checkout --orphan $branch
    git rm -rfq --ignore-unmatch .
fi
