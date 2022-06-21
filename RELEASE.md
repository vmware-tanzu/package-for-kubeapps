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

While connected to the VMware VPN, visit the Harbor instance at [projects.registry.vmware.com](https://projects.registry.vmware.com) and login with your vmware credentials (your username without email). Search for the kubeapps project, for which you should have been given an Admin role, select the project and you will be presented with the single kubeapps/kubeapps repository.

Click on the Robot Accounts tab then New Robot Account and create a bot account with a name such as `release-bot-local-<your username>` with an appropriate expiry. Copy the secret and then in your terminal use:

```bash
docker login projects.registry.vmware.com -u 'robot$kubeapps+release-bot-local-<your username>'
```

and enter the copied secret. You should then see a "Login Succeeded" message.

### Access to the staging repository

A similar process is used for the staging harbor instance at [projects-stg.registry.vmware.com](https://projects-stg.registry.vmware.com), with the difference that we don't have our own kubeapps project there and so the script is configured to push to the tce/kubeapps repository. You will need a developer role to push there. As we don't control the project, neither can we create robot accounts, so you will need to `docker login` with your own credentials, which is not ideal. I have requested a separate kubeapps project on projects-stg that we can administer.

## Running the script

With the above dependencies available, you can only test-run the `package-kubeapps-version.sh` to push a new package to the staging (or production) registry while connected to the VPN (See [Issue #12](https://github.com/vmware-tanzu/package-for-kubeapps/issues/12) for enabling testing the release project with other OCI registries).

The following example runs the script to package the 8.0.10 version of the Bitnami chart. It uses an explicit suffix for the package version (`-dev1`) only because the `8.0.10` version of the package already exists:

```bash
$ ./package-kubeapps-version.sh -s '-dev1' 8.0.10
creating: /.../package-for-kubeapps/8.0.10-dev1/bundle/vendir.yml
Info: Syncing Kubeapps chart 8.0.10 via vendir to /.../package-for-kubeapps/8.0.10-dev1/bundle.
Info: Generating the json-schema for the chart and converting to yaml
Info: Copying README to version directory.
Info: Generating image lock file for Kubeapps 8.0.10
...
Info: Generating /.../package-for-kubeapps/8.0.10-dev1/package.yaml
creating: /.../package-for-kubeapps/8.0.10-dev1/package.yaml
Info: Pushing projects-stg.registry.vmware.com/tce/kubeapps:8.0.10-dev1 image.
Info: Testing installation of new package 8.0.10-dev1
Creating cluster "kubeapps-carvel-e2e" ...
 ✓ Ensuring node image (kindest/node:1.21.1) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
...
Package install reconciled successfully. Deleting...
...
Uninstalled package 'kubeapps' from namespace 'default'
Deleting cluster "kubeapps-carvel-e2e" ...
Info: Skipping creation of release for staging test.
Info: Finished. To test the package manually (until automated tests) you can make the package available on your cluster with:
Info: kubectl apply -n kapp-controller-packaging-global -f ./metadata.yaml -f ./8.0.10-dev1/package.yaml
Info: and install with:
Info: tanzu package install kubeapps --package-name kubeapps.community.tanzu.vmware.com --version 8.0.10-dev1
```

Given that the above was a non-production run against the staging registry, the generated local files will not be committed or tagged nor will a GitHub release have been created. You can delete the generated files to put your local git repository back to its initial state.

For a production release you will need to run the script with the `-p` option which, in addition to pushing the image to the production registry, will also add, commit and tag the new files locally, push the tag to the `upstream` remote and create the release. The script does not currently push your updated branch with the new commits upstream, see [Issue 20](https://github.com/vmware-tanzu/package-for-kubeapps/issues/20).

## Overview of the packaging script

The functionality for creating, testing and publishing a new Kubeapps carvel package is contained primarily in the [package-kubeapps-version.sh bash script](./package-kubeapps-version.sh), with the test-related functionality in the separate [test/testing-lib.sh](./test/testing-lib.sh).

Where possible, effort has been made to utilise the related carvel tooling such as vendir, ytt and imgpkg.

A number of [remaining improvements to the packaging release process have been documented as issues](https://github.com/vmware-tanzu/package-for-kubeapps/issues) but have not yet been raised in priority.
