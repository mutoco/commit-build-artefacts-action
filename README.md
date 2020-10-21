# Commit build artefacts action

A GitHub Action to commit build artefacts to another repository.

**Word of advice**: Only run this on push.

## Inputs

### `source`

**Optional** The build output directory. Default `"./build"`.

### `suffix`
**Optional** The suffix for the build repository. Default `"-build"`. 
So if your repository is named `hello-world`, the build repository will be
`hello-world-build`. 

## Configuration

The following environment variables must be set in order for this
script to run.

### `GITHUB_API_ACCESS_TOKEN`

**Required** Provide an API token with permissions to create a repository.
Instructions on [creating a personal access token](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token).

Make sure to tick the `repo` permission group.

### `GITHUB_API_USERNAME`

**Required** Set the username that belongs to the access token. 

## Example usage
```yaml
uses: actions/commit-build-artefacts-action@latest
with:
  source: './compiled'
```

Inspired by [HV-Publish](https://bitbucket.org/hinderlingvolkart/hv-publish/src/master/)
