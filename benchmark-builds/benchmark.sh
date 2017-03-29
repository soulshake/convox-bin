#!/bin/bash
# So try that app on i3.large, m4.large, and c4.large and share the build times

set -e
set -o pipefail
set -x

export CONVOX_WAIT=true

###### Modify at will #######
STACK_NAME='rails-deleteme'
RACK_NAME="squirrels/${STACK_NAME}"
REPO_URL='git@github.com:convox-examples/rails5.git'
GIT_DIR_NAME='rails5'
BUILD_INSTANCE_TYPE='t2.large'
#############################

die() { echo $*; sleep 3 && exit 1; }

create_rack() {
    stack_name=$1
    [ -z $stack_name ] && die "need stack name"
    echo "[[ convox install --stack-name $stack_name --build-instance "${BUILD_INSTANCE_TYPE}" ]]"
    convox install --stack-name "$stack_name" --build-instance "${BUILD_INSTANCE_TYPE}"
}

wait_until_rack_is_running() {
    while true; do
        status=$(rack_status)
        echo "rack $(convox switch) status: $status"

        case $status in
        running)
            ;;
        *)
            sleep 5
            ;;
        esac

        [[ $status == "running" ]] && return
    done
}

wait_until_app_is_running() {
    while true; do
        status=$(app_status)
        echo "app $(cat .convox/app) status: $status"
        [[ $status == "running" ]] && break
        sleep 5
    done
    # sleep more for good measure
    sleep 10
}

rack_status() {
    convox rack | grep ^Status | awk '{ print $2 }'
}

app_status() {
    convox apps info | grep ^Status | awk '{ print $2 }'
}

clone_repo() {
    if [ ! -d ${GIT_DIR_NAME} ]; then
        echo "[[ git clone '${REPO_URL}' '${GIT_DIR_NAME}' ]]"
        git clone "${REPO_URL}" "${GIT_DIR_NAME}"
    fi
}

create_app() {
    echo "[[ convox apps create ]]"
    convox apps create
}

create_build() {
    # use a subshell so we don't have to worry about which directory we're in
    (
        cd "${GIT_DIR_NAME}"
        start=`date +%s`
        echo "[[ convox builds create ]]"
        echo "START: $start"
        convox builds create
        end=`date +%s`
        echo "END: $end"
        runtime=$((end-start))
        echo "RUNTIME: $runtime"
    )
}

delete_stack() {
    aws cloudformation delete-stack --stack-name "${STACK_NAME}"
}

setup_new_rack_and_app() {
    create_rack "$STACK_NAME" \
        && wait_until_rack_is_running \
        && clone_repo \
        && create_app \
        && wait_until_app_is_running
}

stack_exists() {
    aws cloudformation describe-stacks \
        --region $AWS_DEFAULT_REGION \
        --stack-name "${STACK_NAME}" \
        --query 'Stacks[*].Outputs[?OutputKey==`Dashboard`].OutputValue'
}

wait_until_stack_deleted() {
    while true; do
        status=$(aws cloudformation describe-stacks --region $AWS_DEFAULT_REGION --stack-name ${STACK_NAME} --query 'Stacks[*].StackStatus')
        [ $? -ne 0 ] && echo "Stack ${STACK_NAME} does not exist" && break

        status=$(echo $status | tr -d '[]\n"')
        echo "Stack ${STACK_NAME} status: $status"
        sleep 10
    done
}

current_build_instance_type() {
    convox rack params get BuildInstance \
        | grep ^BuildInstance \
        | awk '{print $2}'
}

fresh_build_instance() {
    build_instance_type="$1"
    [ -z $build_instance_type ] && die "Need build instance type"
    wait_until_rack_is_running
    if [[ $build_instance_type == $(current_build_instance_type) ]]; then
        convox rack params set BuildInstance=
        wait_until_rack_is_running
    fi
    convox rack params set "BuildInstance=$build_instance_type"

}

timed_double_build() {
    echo "-------------- build 1 --------------" \
        && create_build \
        && echo "-------------- build 2 --------------" \
        && create_build
}

stack_exists && delete_stack ${STACK_NAME} && wait_until_stack_deleted
#setup_new_rack_and_app

echo ${RACK_NAME} > .convox/rack
echo ${GIT_DIR_NAME} > .convox/app
mkdir -p ${GIT_DIR_NAME}/.convox
ln -sf $PWD/.convox/rack ${GIT_DIR_NAME}/.convox
ln -sf $PWD/.convox/app ${GIT_DIR_NAME}/.convox

#fresh_build_instance ${BUILD_INSTANCE_TYPE}
#timed_double_build
