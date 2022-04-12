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
readonly template_dir="$script_dir/packaging-templates"
readonly build_dir="$script_dir/build"
readonly red='\033[0;31m'
readonly green='\033[0;32m'
readonly reset_color='\033[0m'
registry_domain=projects-stg.registry.vmware.com
registry_project=tce
packaging_version_suffix=""
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)
version=""

main() {
  get_options "${@}"

  local version_dir="$script_dir/$version$packaging_version_suffix"
  local bundle_dir="$version_dir/bundle"

  if [ -d "$version_dir" ]; then
    error "The directory $version_dir already exists. Remove this directory and re-run to re-create the package bundle for $version."
    exit 1
  fi

  # Create the vendir config for the chart.
  ytt -f "$template_dir/vendir.yml" --data-value-yaml version="$version" --output-files "$bundle_dir"

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
  ytt -f "$template_dir/package.yaml" --data-value-yaml version="$version$packaging_version_suffix" --data-value-yaml releasedAt="$(date --utc +'%Y-%m-%dT%H:%M:%SZ')" --data-value-yaml registry_domain="$registry_domain" --data-value-yaml registry_project="$registry_project" --data-values-file "$yaml_schema" --output-files "$version_dir/"

  # The packaging directory structure wants the packaging README in
  # the top level for the version.
  info "Copying README to version directory."
  cp "$bundle_dir/config/kubeapps/README.md" "$version_dir/"

  # Generate the image lock file for the kubeapps bundle.
  # TODO(minelson): Need to do this more completely, to additionally include
  # non-deployment image values etc. Perhaps just use yq to get all image
  # references and create fake deplyoments. Not sure yet.
  info "Generating image lock file for Kubeapps $version"
  cp "$script_dir/packaging-templates/kbld_config.yml" "$bundle_dir/"
  mkdir -p "$bundle_dir/.imgpkg"
  helm template "$bundle_dir/config/kubeapps" | kbld -f "$bundle_dir/kbld_config.yml" -f - --imgpkg-lock-output "$bundle_dir/.imgpkg/images.yml" 1> /dev/null

  # TODO(minelson): Eventually get the sha from the bundle lock to put in the
  # package.yaml rather than the tag.
  info "Pushing $registry_project/kubeapps:$version$packaging_version_suffix image to registry $registry_domain ."
  imgpkg push --bundle "$registry_domain/$registry_project/kubeapps:$version$packaging_version_suffix" -f "$bundle_dir" --lock-output "$build_dir/kubeapps-lock-file.yaml" 1> /dev/null

  info "Finished. To test the package manually (until automated tests) you can make the package available on your cluster with:"
  info "kubectl apply -n kapp-controller-packaging-global -f ./metadata.yaml -f ./$version$packaging_version_suffix/package.yaml"
  info "and install with:"
  info "tanzu package install kubeapps --package-name kubeapps.community.tanzu.vmware.com --version $version$packaging_version_suffix"
}

# Helpers
get_options() {
  while getopts ":hps:" opt; do
    case $opt in
      h)
        print_usage
        exit 0
        ;;
      p)
        export registry_domain=projects.registry.vmware.com
        export registry_project=kubeapps
        ;;
      s)
        # Support adding a suffix to the version name such as -dev1
        export packaging_version_suffix="$OPTARG"
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
}

print_usage() {
  cat <<EOF
Usage: $script_name [-hsp] CHART_VERSION

  -h         display help
  -s SUFFIX  set the carvel package version suffix to SUFFIX
  -p         use the production registry and project rather than staging
EOF
}

error() {
  printf "${red}Error:${reset_color} %s\\n" "${*}" 1>&2
}

info() {
  printf "${green}Info:${reset_color} %s\\n" "${*}" 1>&2
}

main "${@}"
