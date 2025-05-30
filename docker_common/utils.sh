build_container_image() {
    echo "# ${FUNCNAME[0]} ..."
    FULL_IMAGE_NAME=$REPO_NAME/$IMAGE_NAME
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
    # Prepare build area.
    #tar -czh . | docker build $OPTS -t $IMAGE_NAME -
    DIR="../tmp.build"
    if [[ -d $DIR ]]; then
        rm -rf $DIR
    fi;
    cp -Lr . $DIR || true
    # Build container.
    echo "DOCKER_BUILDKIT=$DOCKER_BUILDKIT"
    echo "DOCKER_BUILD_MULTI_ARCH=$DOCKER_BUILD_MULTI_ARCH"
    if [[ $DOCKER_BUILD_MULTI_ARCH != 1 ]]; then
        # Build for a single architecture.
        echo "Building for current architecture..."
        OPTS="--progress plain $@"
        (cd $DIR; docker build $OPTS -t $FULL_IMAGE_NAME . 2>&1 | tee ../docker_build.log; exit ${PIPESTATUS[0]})
    else
        # Build for multiple architectures.
        echo "Building for multiple architectures..."
        OPTS="$@"
        export DOCKER_CLI_EXPERIMENTAL=enabled
        # Create a new builder.
        #docker buildx rm --all-inactive --force
        #docker buildx create --name mybuilder
        #docker buildx use mybuilder
        # Use the default builder.
        docker buildx use multiarch
        docker buildx inspect --bootstrap
        # Note that one needs to push to the repo since otherwise it is not possible to keep multiple 
        (cd $DIR; docker buildx build --push --platform linux/arm64,linux/amd64 $OPTS --tag $FULL_IMAGE_NAME . 2>&1 | tee ../docker_build.log; exit ${PIPESTATUS[0]})
        # Report the status.
        docker buildx imagetools inspect $FULL_IMAGE_NAME
    fi;
    # Report build version.
    rm docker_build.version.log
    (cd $DIR; docker run --rm -it -v $(pwd):/data $FULL_IMAGE_NAME bash -c "/data/version.sh") 2>&1 | tee docker_build.version.log
    #
    docker image ls $REPO_NAME/$IMAGE_NAME
    echo "*****************************"
    echo "SUCCESS"
    echo "*****************************"
}


remove_container_image() {
    echo "# ${FUNCNAME[0]} ..."
    FULL_IMAGE_NAME=$REPO_NAME/$IMAGE_NAME
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
    docker image ls | grep $FULL_IMAGE_NAME
    docker image ls | grep $FULL_IMAGE_NAME | awk '{print $1}' | xargs -n 1 -t docker image rm -f
    docker image ls
    echo "${FUNCNAME[0]} ... done"
}


push_container_image() {
    echo "# ${FUNCNAME[0]} ..."
    FULL_IMAGE_NAME=$REPO_NAME/$IMAGE_NAME
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
    docker login --username $REPO_NAME --password-stdin <~/.docker/passwd.$REPO_NAME.txt
    docker images $FULL_IMAGE_NAME
    docker push $FULL_IMAGE_NAME
    echo "${FUNCNAME[0]} ... done"
}


pull_container_image() {
    echo "# ${FUNCNAME[0]} ..."
    FULL_IMAGE_NAME=$REPO_NAME/$IMAGE_NAME
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
    docker pull $FULL_IMAGE_NAME
    echo "${FUNCNAME[0]} ... done"
}


kill_container() {
    echo "# ${FUNCNAME[0]} ..."
    FULL_IMAGE_NAME=$REPO_NAME/$IMAGE_NAME
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
    docker container ls
    #
    CONTAINER_ID=$(docker container ls -a | grep $FULL_IMAGE_NAME | awk '{print $1}')
    echo "CONTAINER_ID=$CONTAINER_ID"
    if [[ ! -z $CONTAINER_ID ]]; then
        docker container rm -f $CONTAINER_ID
        docker container ls
    fi;
    echo "${FUNCNAME[0]} ... done"
}


exec_container() {
    echo "# ${FUNCNAME[0]} ..."
    FULL_IMAGE_NAME=$REPO_NAME/$IMAGE_NAME
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
    docker container ls
    #
    CONTAINER_ID=$(docker container ls -a | grep $FULL_IMAGE_NAME | awk '{print $1}')
    echo "CONTAINER_ID=$CONTAINER_ID"
    docker exec -it $CONTAINER_ID bash
    echo "${FUNCNAME[0]} ... done"
}


get_docker_vars_script() {
    local local_dir=$1
    # Find the name of the container.
    SCRIPT_DIR=$(cd -- "$(dirname -- local_dir)" &> /dev/null && pwd)
    DOCKER_NAME="$SCRIPT_DIR/docker_name.sh"
    if [[ ! -e $SCRIPT_DIR ]]; then
        echo "Can't find $DOCKER_NAME"
        exit -1
    fi;
    source $DOCKER_NAME
}


print_docker_vars() {
    echo "REPO_NAME=$REPO_NAME"
    echo "IMAGE_NAME=$IMAGE_NAME"
    echo "FULL_IMAGE_NAME=$FULL_IMAGE_NAME"
}


run() {
    cmd="$*"
    echo "> $cmd"
    eval "$cmd"
}
