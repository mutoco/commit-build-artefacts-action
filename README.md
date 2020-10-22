# Commit build artefacts action

A GitHub Action to commit build artefacts to another repository.

Use case: You want to (continuously) hand over build artefacts to a third party. 
By using this action, you can push the contents of your build-process to a separate repository.

The build-repository will get generated automatically. Branches will be mirrored.

**Word of advice**: Only run this on push.

## Inputs

#### `source`

**Optional** The build output directory. Default `"build"`.

#### `suffix`

**Optional** The suffix for the build repository. Default `"-build"`. 
So if your repository is named `hello-world`, the build repository will be
`hello-world-build`. 

#### `organisation`

**Optional** If the build-repo should belong to an organisation, set the
organisation here. Otherwise, the repository will be created for your user.

**Important**: Your user (see [Configuration](#Configuration)) needs to have permissions to create repositories in that organisation

#### `committer_name`

**Optional** The user that will show up as the committer on the build repo.
Defaults to `"Anonymous"`

#### `committer_email`

**Optional** The email that will be used for the committer on the build-repo.
Is empty by default

## Configuration

The following environment variables must be set in order for this
script to run.

#### `GITHUB_API_ACCESS_TOKEN`

**Required** Provide an API token with permissions to create a repository.
Instructions on [creating a personal access token](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token).

Make sure to tick the `repo` permission group.

#### `GITHUB_API_USERNAME`

**Required** Set the username that belongs to the access token.

## Example usage

Please make sure to use the `actions/checkout@v2` beforehand.
You'd also need some action that creates your build artefacts 
(unless you just want to just export a specific folder to the build repo).

```yaml
name: Deploy
on:
  push:
    branches:
      - master

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0 # get history for commit messages
      - uses: # some action that creates a build
      - uses: actions/commit-build-artefacts-action@latest
        with:
          source: 'compiled'
          organisation: example
          committer_name: Build-Tools
          committer_email: email@example.com
        env:
          GITHUB_API_USERNAME: username
          GITHUB_API_ACCESS_TOKEN: ${{ secrets.MY_GITHUB_PAT }}
```

Inspired by [HV-Publish](https://bitbucket.org/hinderlingvolkart/hv-publish/src/master/)
