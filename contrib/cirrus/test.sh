#!/usr/bin/env bash

set -e

source $(dirname $0)/lib.sh

req_env_var IN_PODMAN IN_PODMAN_NAME GOSRC 1

if [[ "$IN_PODMAN" == "true" ]]
then
    cd $GOSRC
    # Host build environment != container environment
    showrun make clean
    in_podman --rm $IN_PODMAN_NAME:latest $0 $1
elif [[ -z "$CROSS_TARGET" ]]
then
    cd $GOSRC

    showrun make
    showrun make install.tools

    case $1 in
        validate)
            showrun ooe.sh git remote add upstream "$CIRRUS_REPO_CLONE_URL"
            showrun ooe.sh git remote update
            if [[ -z "$CIRRUS_PR" ]]
            then
                echo "Testing a branch, assumed or based on the $DEST_BRANCH brach from .cirrus.yml"
                export GITVALIDATE_EPOCH="$(git rev-parse upstream/$DEST_BRANCH)"
            else  # Testing a PR
                echo "Testing a PR targeted at the $DEST_BRANCH branch"
                export GITVALIDATE_EPOCH="$CIRRUS_BASE_SHA" # relative to $CIRRUS_BASE_BRANCH
            fi
            export GITVALIDATE_TIP="$CIRRUS_CHANGE_IN_REPO"
            echo "Linting & Validating from $GITVALIDATE_EPOCH to $GITVALIDATE_TIP"
            # Required for specifying our own commit range to git-validate.sh
            export TRAVIS=true
            # The big 'Golint: can't lint 3 files...' warning puke, harmless and fixed in v1.20.0
            showrun make lint
            # TODO: This will fail if PR HEAD != upstream branch head
            showrun make validate
            ;;
        unit)
            showrun make test-unit
            ;;
        integration)
            showrun make test-integration
            ;;
        *)
            die 1 "First parameter to $(basename $0) not supported: '$1'"
            ;;
    esac
else
    echo "Testing a cross-compiled $CROSS_TARGET target not possible on this platform"
fi
