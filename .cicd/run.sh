#!/usr/bin/env bash
set -eo pipefail
. ./.cicd/helpers/general.sh
. ./$HELPERS_DIR/execute.sh
if [[ $(uname) == Darwin ]]; then

    cd $ROOT_DIR
    ccache -s
    mkdir -p build
    cd build
    if [[ $BUILDKITE ]]; then
        if [[ $ENABLE_BUILD ]]; then
            execute cmake ..
            execute make -j$JOBS
        elif [[ $ENABLE_TEST ]]; then
            execute ctest -j$JOBS -V --output-on-failure -T Test
        fi
    elif [[ $TRAVIS ]]; then
        execute cmake ..
        execute make -j$JOBS
        #execute ctest -j$JOBS -V --output-on-failure -T Test
    fi

else # Linux

    . ./$HELPERS_DIR/docker.sh
    . ./$HELPERS_DIR/docker-hash.sh

    execute mkdir -p $ROOT_DIR/build

    BUILD_COMMANDS="cd /workdir/build && cmake -DCMAKE_TOOLCHAIN_FILE=/workdir/.cicd/helpers/clang.make -DENABLE_TESTS=ON .. && make -j$JOBS"
    TEST_COMMANDS="cd /workdir/build && ctest -j$JOBS -V --output-on-failure -T Test"

    # Docker Run Arguments
    ARGS=${ARGS:-"--rm -v $(pwd):/workdir"}
    # Docker Commands
    if [[ $BUILDKITE ]]; then
        # Generate Base Images
        execute ./.cicd/generate-base-images.sh
        [[ ! -d $ROOT_DIR/build/wasms ]] && execute git clone git@github.com:EOSIO/eos-vm-test-wasms.git $ROOT_DIR/build/wasms # support for private wasm repo (contact Bucky)
        [[ $ENABLE_BUILD ]] && append-to-commands $BUILD_COMMANDS
        [[ $ENABLE_TEST ]] && append-to-commands $TEST_COMMANDS
    elif [[ $TRAVIS ]]; then
        echo HERE
        execute mkdir $ROOT_DIR/build/wasms
        ARGS="$ARGS -v /usr/lib/ccache -v $HOME/.ccache:/opt/.ccache -e JOBS -e CCACHE_DIR=/opt/.ccache"
        COMMANDS="ccache -s && $BUILD_COMMANDS"
    fi

    # Docker Run
    docker-run $COMMANDS

fi