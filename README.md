# Auto Go Format

This github action automatically formats your golang files in pull requests and
pushes them. :rocket:

## Installation

Create a workflow yaml file (eg: `.github/workflows/go-format.yml` see
[Creating a Workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file)):

```yml
name: Golang Formatter
on: [pull_request]
jobs:
  build:
    name: Golang Formatter
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
      with:
        fetch-depth: 0
    - name: Golang Formatter
      uses: dingdayu/auto-go-format@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
