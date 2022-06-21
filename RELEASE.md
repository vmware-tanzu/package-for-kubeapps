# Releasing a new version of the Kubeapps carvel package for TCE

## Dependencies

Until the script is containerized ([Issue #11](https://github.com/vmware-tanzu/package-for-kubeapps/issues/11)), you will need the following software installed on your local machine:

- The complete [Carvel toolset](https://carvel.dev/#install),
- [Kubernetes in Docker](https://kind.sigs.k8s.io/) for the integration test of the generated package,
- The [GitHub CLI](https://cli.github.com/) for creating the release in the repository,
- The [Helm CLI](https://helm.sh/) for templating out the Bitnami Kubeapps Helm chart when creating the Carvel package.
- Bitnami's [readme-generator-for-helm tool](https://github.com/bitnami-labs/readme-generator-for-helm) for creating the complete json schema for the Carvel package, as well as
- The [yq yaml processor](https://mikefarah.gitbook.io/yq/) to convert the json schema to a yaml schema.

## Repository push access

In addition, you also need permission to be able to push images to the relevant repositories of projects-stg.registry.vmware.com and projects.registry.vmware.com.

### Access to the production projects.registry.vmware.com kubeapps project

Both the staging and production distribution registries have the `tanzu-kubeapps-team` as an admin member for the `kubeapps` project, so you should have access to the project as long as you are a member of that group.

Although this already allows you to pull and push images to the project, you should create a bot account to authenticate and use with the script rather than your own credentials.

While connected to the VMware VPN, visit the Harbor instance at [projects.registry.vmware.com](https://projects.registry.vmware.com) and login with your vmware credentials (your username without email). Search for the kubeapps project, for which you should find you have an Admin role (as part of `tanzu-kubeapps-team`), select the project and you will be presented with the single kubeapps/kubeapps repository.

Click on the Robot Accounts tab then New Robot Account and create a bot account with a name such as `release-bot-local-<your username>` with an appropriate expiry. Copy the secret and then in your terminal use:

```bash
docker login projects.registry.vmware.com -u 'robot$kubeapps+release-bot-local-<your username>'
```

and enter the copied secret. You should then see a "Login Succeeded" message.

### Access to the staging repository

A similar process is now used for the staging harbor instance at [projects-stg.registry.vmware.com](https://projects-stg.registry.vmware.com) since we now have access to an identical kubeapps project on the staging service.

## Running the script

With the above dependencies available, you can only test-run the `package-kubeapps-version.sh` to push a new package to the staging (or production) registry while connected to the VPN (See [Issue #12](https://github.com/vmware-tanzu/package-for-kubeapps/issues/12) for enabling testing the release project with other OCI registries).

The following example runs the script to package the 8.0.14 version of the Bitnami chart. It uses an explicit suffix for the package version (`-dev1`) only because the `8.0.14` version of the package already exists. After ensuring that the version you want to package is already cached in your local helm cache (`helm repo update && helm search repo kubeapps`):

```bash
$ ./package-kubeapps-version.sh -s '-dev1' 8.0.14
creating: /home/michael/dev/vmware/package-for-kubeapps/8.0.14-dev1/bundle/vendir.yml
Info: Syncing Kubeapps chart 8.0.14 via vendir to /home/michael/dev/vmware/package-for-kubeapps/8.0.14-dev1/bundle.
Info: Updating values file to default to carvel support.
Info: Generating the json-schema for the chart and converting to yaml
Info: Copying README to version directory.
Info: Generating image lock file for Kubeapps 8.0.14
Info: Collecting all images to /home/michael/dev/vmware/package-for-kubeapps/build/images.txt
Info: Generating fake deployments for kbld images.
...
Info: Generating /home/michael/dev/vmware/package-for-kubeapps/8.0.14-dev1/package.yaml
creating: /home/michael/dev/vmware/package-for-kubeapps/8.0.14-dev1/package.yaml
Info: Pushing projects-stg.registry.vmware.com/kubeapps/kubeapps:8.0.14-dev1 image.
Info: Testing installation of new package 8.0.14-dev1
Creating cluster "kubeapps-carvel-e2e" ...
 ✓ Ensuring node image (kindest/node:1.21.1) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ...
Package install reconciled successfully. Deleting...
| Uninstalling package 'kubeapps' from namespace 'default'
...
Deleting cluster "kubeapps-carvel-e2e" ...
Info: Skipping creation of release for staging test.
Info: Finished. To test the package manually (until automated tests) you can make the package available on your cluster with:
Info: kubectl apply -n kapp-controller-packaging-global -f ./metadata.yaml -f ./8.0.14-dev1/package.yaml
Info: and install with:
Info: tanzu package install kubeapps --package-name kubeapps.community.tanzu.vmware.com --version 8.0.14-dev1
```

Given that the above was a non-production run against the staging registry, the generated local files will not be committed or tagged nor will a GitHub release have been created. You can delete the generated files to put your local git repository back to its initial state:

```bash
rm 8.0.14-dev1 -rf
```

For a production release you will need to run the script with the `-p` option which, in addition to pushing the image to the production registry, will also add, commit and tag the new files locally, push the tag to the `upstream` remote and create the release. The script does not currently push your updated branch with the new commits upstream, see [Issue 20](https://github.com/vmware-tanzu/package-for-kubeapps/issues/20).

## Updating the TCE repository to include the new package

Once we've published a new package to the production registry, we need to request that the new package be included in the TCE repository via a pull-request.

The [initial pull-request to include Kubeapps in the TCE repository](https://github.com/vmware-tanzu/community-edition/pull/4666) added:

- `addons/packages/kubeapps/metadata.yaml` - the metadata which tends not to change with new versions,
- `addons/packages/kubeapps/vendir.yml` - a vendir configuration which specifies the GitHub release from which to pull the README.md and `package.yaml` and where to place them.

The vendir tool was then run in the `addons/packages/kubeapps` directory to ensure all files are in place, before committing and creating the PR.

Subsequent updates for the Kubeapps package in TCE will involve modifying the `vendir.yml` to add a new path for the next release and re-running vendir before creating the PR. You can see example PRs like this for other packages, such as the [update PR for the FluxCD Helm Controller package](https://github.com/vmware-tanzu/community-edition/pull/4611/files) which adds a new `path` to the vendir.yml which is vendir'd as well as a minor manual update to the metadata.yaml (adding an icon).

## Overview of the packaging script

The functionality for creating, testing and publishing a new Kubeapps carvel package is contained primarily in the [package-kubeapps-version.sh bash script](./package-kubeapps-version.sh), with the test-related functionality in the separate [test/testing-lib.sh](./test/testing-lib.sh).

Where possible, effort has been made to utilise the related carvel tooling such as vendir, ytt and imgpkg.

A number of [remaining improvements to the packaging release process have been documented as issues](https://github.com/vmware-tanzu/package-for-kubeapps/issues) but have not yet been raised in priority.

The functionality of the script is based on the [recommendations of the TCE packaging documentation](https://github.com/vmware-tanzu/community-edition/tree/main/docs/packaging).
