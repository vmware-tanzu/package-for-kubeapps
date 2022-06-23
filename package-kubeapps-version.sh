#! /usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Variables
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
readonly template_dir="$script_dir/packaging-templates"
readonly build_dir="$script_dir/build"
readonly red='\033[0;31m'
readonly green='\033[0;32m'
readonly reset_color='\033[0m'
# TODO(minelson): Update staging project once we have access. For now
# we can keep pushing to the staging tce project.
readonly staging_oci_repo="projects-stg.registry.vmware.com/tce/kubeapps"
readonly production_oci_repo="projects.registry.vmware.com/kubeapps/kubeapps"
readonly logfile="/tmp/package-kubeapps-version.log"
readonly default_values_file="$template_dir/default-values.yaml"

source test/testing-lib.sh

# Default to staging repo for development work unless production specified.
oci_repo="$staging_oci_repo"
# version will be set by get_options.
version=""

packaging_version_suffix=""
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)

main() {
  get_options "${@}"

  local version_dir="$script_dir/$version$packaging_version_suffix"
  local bundle_dir="$version_dir/bundle"
  local yaml_schema="$build_dir/kubeapps-$version-schema.yaml"

   mkdir -p "$build_dir"

  check_no_overwrite "$version_dir"

  sync_chart_via_vendir "$template_dir/vendir.yml" "$version" "$version_dir"

  update_default_values "$bundle_dir/config/kubeapps/values.yaml"

  regenerate_readme_and_schema "$version" "$bundle_dir" "$yaml_schema"

  # The packaging directory structure wants the packaging README in
  # the top level for the version.
  info "Copying README to version directory."
  cp "$bundle_dir/config/kubeapps/README.md" "$version_dir/"

  generate_image_lock_file "$bundle_dir"

  # Generate the package yaml for the staging release first.
  generate_package_yaml "$version" "$packaging_version_suffix" "$version_dir" "$yaml_schema" "$oci_repo"

  # TODO(minelson): Eventually get the sha from the bundle lock to put in the
  # package.yaml rather than the tag.
  info "Pushing $oci_repo:$version$packaging_version_suffix image."
  imgpkg push --bundle "$oci_repo:$version$packaging_version_suffix" -f "$bundle_dir" --lock-output "$build_dir/kubeapps-lock-file.yaml" 1> "$logfile"

  info "Testing installation of new package $version$packaging_version_suffix"
  setup_kind_cluster
  install_kubeapps "$version$packaging_version_suffix"
  delete_kind_cluster

  # Commit, tag and create a release for production only.
  if [ "$oci_repo" = "$production_oci_repo" ]; then
    create_release "$version" "$packaging_version_suffix"
  else
    info "Skipping creation of release for staging test."
  fi

  info "Finished. To test the package manually (until automated tests) you can make the package available on your cluster with:"
  info "kubectl apply -n kapp-controller-packaging-global -f ./metadata.yaml -f ./$version$packaging_version_suffix/package.yaml"
  info "and install with:"
  info "tanzu package install kubeapps --package-name kubeapps.community.tanzu.vmware.com --version $version$packaging_version_suffix"
}

# Helpers
check_no_overwrite() {
  local version_dir=$1

  if [ -d "$version_dir" ]; then
    error "The directory $version_dir already exists. Remove this directory and re-run to re-create the package bundle for this version."
    exit 1
  fi
}

create_release() {
  local version=$1
  local packaging_version_suffix=$2
  local version_with_suffix="$version$packaging_version_suffix"
  local tag="v$version_with_suffix"
  git add "./$version_with_suffix"
  git commit -m "Adding $tag files"
  info "Committing files and tagging $tag for release"
  git tag "$tag" -m "$tag"
  git push upstream "tags/$tag"

  info "Creating release for $tag"
  gh release create "$tag" "./$version_with_suffix/package.yaml" "./metadata.yaml" "./README.md" \
    --repo vmware-tanzu/package-for-kubeapps \
    --notes-file "$template_dir/release-notes.md"
}

generate_image_lock_file() {
  # Generate the image lock file for the kubeapps bundle.
  # TODO(minelson): Need to do this more completely, to additionally include
  # non-deployment image values etc. Perhaps just use yq to get all image
  # references and create fake deplyoments. Not sure yet.
  info "Generating image lock file for Kubeapps $version"
  local bundle_dir=$1

  info "Collecting all images to $build_dir/images.txt"
  find 8.0.14 -name "values.yaml" -exec yq '... | select(has("image")) | .image.registry + "/" + .image.repository + ":" + .image.tag' {} \; | uniq > "$build_dir/images.txt"
  find 8.0.14 -name "values.yaml" -exec yq '... | select(has("syncImage")) | .syncImage.registry + "/" + .syncImage.repository + ":" + .syncImage.tag' {} \; | uniq >> "$build_dir/images.txt"

  info "Generating fake deployments for kbld images."
  cp "$template_dir/kbld_config.yml" "$bundle_dir/"
  mkdir -p "$bundle_dir/.imgpkg"
  ytt -f "$build_dir/images.txt" -f "$template_dir/kbld_fake_deployments.yml" | kbld -f - --imgpkg-lock-output "$bundle_dir/.imgpkg/images.yml" 1> "$logfile"
}

generate_package_yaml() {
  info "Generating $version_dir/package.yaml"
  local version=$1
  local packaging_version_suffix=$2
  local version_dir=$3
  local yaml_schema=$4
  local oci_repo=$5
  # Create the versioned package yaml. Initially this uses a tag for the
  # imgpkgBundle, we may need to update to a sha at some point.
  ytt -f "$template_dir/package.yaml" \
    --data-value-yaml version="$version$packaging_version_suffix" \
    --data-value-yaml releasedAt="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --data-value-yaml ociRepo="$oci_repo" \
    --data-values-file "$yaml_schema" \
    --output-files "$version_dir/"
}

regenerate_readme_and_schema() {
  local version=$1
  local bundle_dir=$2
  local yaml_schema=$3
  # Generate the full json-schema for the chart.
  # Note: the values-schema.json in the bitnami Kubeapps chart is just
  # for the simple forms support.
  info "Generating the json-schema for the chart and converting to yaml"
  local json_schema="$build_dir/kubeapps-$version-schema.json"
  readme-generator -v "$bundle_dir/config/kubeapps/values.yaml" --readme "$bundle_dir/config/kubeapps/README.md" --schema "$json_schema" >"$logfile" 2>&1
  yq -P "$json_schema" > "$yaml_schema"
}

get_options() {
  while getopts ":hps:" opt; do
    case $opt in
      h)
        print_usage
        exit 0
        ;;
      p)
        export oci_repo="$production_oci_repo"
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

update_default_values() {
  local values_file=$1

  info "Updating values file to default to carvel support."
  yq eval-all --inplace '. as $item ireduce ({}; . *+ $item )' $values_file $default_values_file
}

sync_chart_via_vendir(){
  local vendir_yml=$1
  local version=$2
  local version_dir=$3
  # Create the vendir config for the chart.
  ytt -f "$vendir_yml" --data-value-yaml version="$version" --output-files "$bundle_dir"

  info "Syncing Kubeapps chart $version via vendir to $bundle_dir."
  vendir --chdir "$bundle_dir" sync > "$logfile"
}

error() {
  printf "${red}Error:${reset_color} %s\\n" "${*}" 1>&2
}

info() {
  printf "${green}Info:${reset_color} %s\\n" "${*}" 1>&2
}

err_report() {
    if [ "$1" != "0" ]; then
      echo "Error $1 occurred on $2. View logs in $logfile"
    fi
}

trap 'err_report $? $LINENO' EXIT

main "${@}"
