#! /usr/bin/env bash

# Bash settings
# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail

# Variables
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
readonly TEMPLATE_DIR="$script_dir/packaging-templates"
readonly build_dir="$script_dir/build"
readonly red='\033[0;31m'
readonly green='\033[0;32m'
readonly reset_color='\033[0m'
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)
version=""

main() {
  get_options "${@}"

  local version_dir="$script_dir/$version"
  local bundle_dir="$version_dir/bundle"

  # Create the vendir config for the chart.
  ytt -f "$TEMPLATE_DIR/vendir.yml" --data-value-yaml version="$version" --output-files "$bundle_dir"

  info "Syncing Kubeapps chart $version via vendir."
  vendir --chdir "$bundle_dir" sync > /dev/null

  # Generate the full json-schema for the chart.
  # Note: the values-schema.json in the bitnami Kubeapps chart is just
  # for the simple forms support.
  info "Generating the json-schema for the chart and converting to yaml"
  local json_schema="$build_dir/kubeapps-$version-schema.json"
  readme-generator -v "$bundle_dir/config/kubeapps/values.yaml" --schema "$json_schema" >/dev/null 2>&1
  local yaml_schema="$build_dir/kubeapps-$version-schema.yaml"
  yq -P "$json_schema" > "$yaml_schema"

  # Create the versioned package yaml. Initially this uses a tag for the
  # imgpkgBundle, we may need to update to a sha at some point.
  ytt -f "$TEMPLATE_DIR/package.yaml" --data-value-yaml version="$version" --data-value-yaml releasedAt="$(date --utc +'%Y-%m-%dT%H:%M:%SZ')" --data-values-file "$yaml_schema" --output-files "$version_dir/"

  # TODO: add the .imgpkg hidden file. Use yq to get all image references
  # from values.yaml of chart and subcharts to compile list? (also syncImage from kubeapps)

  # The packaging directory structure wants the packaging README in
  # the top level for the version.
  info "Copying README to version directory."
  cp "$bundle_dir/config/kubeapps/README.md" "$version_dir/"

  # TODO: Push to registry and get the sha for the package.yaml

  info "Finished."
}

# Helpers
get_options() {
  while getopts ":h" opt; do
    case $opt in
      h)
        print_usage
        exit 0
        ;;
      \?)
        error "Invalid option: -$OPTARG"
        print_usage
        exit 1
        ;;
      :)
        error "Option -$OPTARG requires an argument"
        print_usage
        exit 1
        ;;
    esac
  done
  # Get remaining args
  shift $((OPTIND - 1))
  if [ "$#" -ne 1 ]; then
    error "Exactly 1 required argument for the version. $# found."
    print_usage
    exit 1
  fi
  export version=$1

  local version_dir="$script_dir/$version"
  if [ -d "$version_dir" ]; then
    error "The directory $version_dir already exists. Remove this directory and re-run to re-create the package bundle for $version."
    exit 1
  fi
}

print_usage() {
  cat <<EOF
Usage: $script_name [OPTIONS] bitnami-chart-version
EOF
}

error() {
  printf "${red}Error:${reset_color} %s\\n" "${*}" 1>&2
}

info() {
  printf "${green}Info:${reset_color} %s\\n" "${*}" 1>&2
}

main "${@}"
