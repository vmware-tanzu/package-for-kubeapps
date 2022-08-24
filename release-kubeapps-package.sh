#! /usr/bin/env bash

# Copyright 2022 the Kubeapps contributors.
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

# Variables
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
readonly template_dir="$script_dir/packaging-templates"
readonly git_repo="vmware-tanzu/package-for-kubeapps"

# Variables set by get_options.
version=""
packaging_version_suffix=""

main() {
  get_options "${@}"
  
  # Commit, tag and create a release for production only.
  echo "Releasing Kubeapps Carvel package v$version to repo '$git_repo'"
  create_release "$version" "$packaging_version_suffix"
}

# Commit, tag and create a release in GitHub.
create_release() {
  local version=$1
  local packaging_version_suffix=$2
  local version_with_suffix="$version$packaging_version_suffix"
  local tag="v$version_with_suffix"
  git add "./$version_with_suffix"
  git commit -m "Adding $tag files"
  echo "Committing files and tagging $tag for release"
  git tag "$tag" -m "$tag"
  # Pick first remote to push
  local git_origin="$(git remote | head -n 1)"
  git push "$git_origin" "tags/$tag"

  echo "Creating release for $tag"
  gh release create "$tag" "./$version_with_suffix/package.yaml" "./metadata.yaml" "./README.md" \
    --repo "$git_repo" \
    --notes-file "$template_dir/release-notes.md"
}

print_usage() {
  cat <<EOF
Usage: $script_name [-hs] CHART_VERSION

  -h         display help
  -s SUFFIX  set the carvel package version suffix to SUFFIX
EOF
}

get_options() {
  while getopts ":hps:" opt; do
    case $opt in
      h)
        print_usage
        exit 0
        ;;
      s)
        # Support adding a suffix to the version name such as -dev1
        export packaging_version_suffix="$OPTARG"
        ;;
      \?)
        echo "Invalid option: -$OPTARG"
        print_usage
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument"
        print_usage
        exit 1
        ;;
    esac
  done
  # Get remaining args
  shift $((OPTIND - 1))
  if [ "$#" -ne 1 ]; then
    echo "Exactly 1 required argument for the version. $# found."
    print_usage
    exit 1
  fi
  export version=$1
}

err_report() {
    if [ "$1" != "0" ]; then
      echo "Error $1 occurred on $2."
    fi
}

trap 'err_report $? $LINENO' EXIT

if [ $# -eq 0 ];then
  echo "No arguments supplied"
  print_usage
  exit 1
fi

main "${@}"
