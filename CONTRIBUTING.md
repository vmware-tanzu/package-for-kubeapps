# Contributing to package-for-kubeapps

The package-for-kubeapps project team welcomes contributions from the community. Before you start working with package-for-kubeapps, please
read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be
signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on
as an open-source patch.

## Running the `package-kubeapps-version.sh` script locally

Until the script is containerized (#11), you will need the following software installed:

- The complete [Carvel toolset](https://carvel.dev/#install),
- [Kubernetes in Docker](https://kind.sigs.k8s.io/) for the integration test of the generated package,
- The [GitHub CLI](https://cli.github.com/) for creating the release in the repository,
- The [Helm CLI](https://helm.sh/) for templating out the Bitnami Kubeapps Helm chart when creating the Carvel package.
- Bitnami's [readme-generator-for-helm tool](https://github.com/bitnami-labs/readme-generator-for-helm) for creating the complete json schema for the Carvel package, as well as
- The [yq yaml processor](https://mikefarah.gitbook.io/yq/) to convert the json schema to a yaml schema.

Currently with these tools installed, you can only test-run the `package-kubeapps-version.sh` to push a new package to the staging (or production) registry if you have VMware VPN access available (#12).

The following example runs the script to package the 8.0.10 version of the Bitnami chart. It uses an explicit suffix for the package version (`-dev1`) only because the `8.0.10` version of the package already exists:

```bash
$ ./package-kubeapps-version.sh -s '-dev1' 8.0.10
creating: /home/michael/dev/vmware/package-for-kubeapps/8.0.10-dev1/bundle/vendir.yml
Info: Syncing Kubeapps chart 8.0.10 via vendir to /home/michael/dev/vmware/package-for-kubeapps/8.0.10-dev1/bundle.
Info: Generating the json-schema for the chart and converting to yaml
Info: Copying README to version directory.
Info: Generating image lock file for Kubeapps 8.0.10
...
Info: Generating /home/michael/dev/vmware/package-for-kubeapps/8.0.10-dev1/package.yaml
creating: /home/michael/dev/vmware/package-for-kubeapps/8.0.10-dev1/package.yaml
Info: Pushing projects-stg.registry.vmware.com/tce/kubeapps:8.0.10-dev1 image.
Info: Testing installation of new package 8.0.10-dev1
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

## Contribution Flow

This is a rough outline of what a contributor's workflow looks like:

- Create a topic branch from where you want to base your work
- Make commits of logical units
- Make sure your commit messages are in the proper format (see below)
- Push your changes to a topic branch in your fork of the repository
- Submit a pull request

Example:

``` shell
git remote add upstream https://github.com/vmware-tanzu/package-for-kubeapps.git
git checkout -b my-new-feature main
git commit -a
git push origin my-new-feature
```

### Staying In Sync With Upstream

When your branch gets out of sync with the vmware-tanzu/main branch, use the following to update:

``` shell
git checkout my-new-feature
git fetch -a
git pull --rebase upstream main
git push --force-with-lease origin my-new-feature
```

### Updating pull requests

If your PR fails to pass CI or needs changes based on code review, you'll most likely want to squash these changes into
existing commits.

If your pull request contains a single commit or your changes are related to the most recent commit, you can simply
amend the commit.

``` shell
git add .
git commit --amend
git push --force-with-lease origin my-new-feature
```

If you need to squash changes into an earlier commit, you can use:

``` shell
git add .
git commit --fixup <commit>
git rebase -i --autosquash main
git push --force-with-lease origin my-new-feature
```

Be sure to add a comment to the PR indicating your new changes are ready to review, as GitHub does not generate a
notification when you git push.

### Code Style

### Formatting Commit Messages

We follow the conventions on [How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/).

Be sure to include any related GitHub issue references in the commit message.  See
[GFM syntax](https://guides.github.com/features/mastering-markdown/#GitHub-flavored-markdown) for referencing issues
and commits.

## Reporting Bugs and Creating Issues

When opening a new issue, try to roughly follow the commit message format conventions above.
