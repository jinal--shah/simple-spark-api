#!/bin/bash
# vim: et sr sw=4 ts=4 smartindent:

# source cfg and libs first to take advantage of common vars and funcs.
! . cfg.sh && echo >&2 "ERROR: could not source common vars file" && exit 1
! . libs.sh && echo >&2 "ERROR: could not source common libs file" && exit 1

export APP_B_DOCKER_TAG="stable" # ... used when provisioning a stack

APP_A_INSTANCES=${APP_A_INSTANCES:-1}
APP_B_INSTANCES=${APP_B_INSTANCES:-1}

TESTS_DIR=$PROJ_ROOT_DIR/integration-tests
PROVISION_DIR=$PROJ_ROOT_DIR/provision-stack

prep_env() { docker pull $GOLANG_IMAGE ; docker pull $CURL_IMAGE ; }

start_stack() {
    local stack_id="$1"
    (
        cd $PROVISION_DIR
        export STACK_ID="$stack_id" # needed for docker-compose yml

        docker stack deploy --compose-file docker-compose.yml $stack_id || return 1
    )
}

scale_instances() {
    local stack_id="$1"
    local opts=""

    [[ $APP_A_INSTANCES -gt 1 ]] && opts="${opts}${stack_id}_appA=$APP_A_INSTANCES "
    [[ $APP_B_INSTANCES -gt 1 ]] && opts="${opts}${stack_id}_appB=$APP_B_INSTANCES "

    if [[ ! -z "$opts" ]]; then
        docker service scale $opts
    fi
}

# ... will wait until appA healthcheck responds
wait_for_service() {
    local stack_id="$1"
    local rc=1

    local retries=5
    local delay=3

    local url="http://${stack_id}_appA:4567/health"
    local net="${stack_id}_stack"
    local curl_container="${stack_id}_curl"
    
    # ... wait until app A healthcheck responds with 200
    while [[ $(( retries-- )) -gt 0 ]]; do
        c="${curl_container}-$(date '+%Y%d%m%H%M%S')"
        [[ "$(run_curl $c $net $url)" == "200" ]] && rc=0 && break
        echo "... waiting for app A /health to respond 200"
        sleep $delay
    done

    if [[ $rc -ne 0 ]]; then
        echo "ERROR: app A healthcheck at $url failed to come up in time ..." >&2
    fi

    # ... clean up any dangling containers
    docker ps -a --filter "name=$curl_container" --format "{{ .ID }}" \
    | xargs -n1 -i{} docker rm -f {} 2>/dev/null

    return $rc
}

run_curl() {
    local name="$1"
    local net="$2"
    local url="$3"
    docker run -t --name "$name" --net $net --rm \
        byrnedo/alpine-curl -Ss -o /dev/null -w '%{http_code}' -I $url 2>/dev/null \
    || echo "000"
}

run_integration_tests() {
    local stack_id="$1"
    local rc=0
    local container="appA_integration_tests-$(date +'%Y%m%d%H%M%S')"

    container_script > $TESTS_DIR/container_script.sh || return 1

    docker run -t --rm --name $container \
        -e APP_A_HOST="${stack_id}_appA:4567" \
        -e LB_HOST="${stack_id}_traefik" \
        --net ${stack_id}_stack \
        -v $TESTS_DIR:/go/src/project \
        -w /go/src/project \
           $GOLANG_IMAGE /bin/sh /go/src/project/container_script.sh || rc=1

    docker rm -f $container 2>/dev/null 
    rm -rf $TESTS_DIR/container_script.sh 2>/dev/null

    return $rc

}

kill_stack() {
    local stack_id="$1"
    local rc=0

    docker stack rm $stack_id || rc=1

    sleep 1

    docker ps -a --filter "name=$stack_id" --format "{{ .ID }}" \
    | xargs -n1 -i{} docker rm -f {} 2>/dev/null

    return $rc
}

main() {
    rc=0

    echo "INFO: prepping env"
    ! prep_env && echo >&2 "ERROR: unable to prep env" && return 1

    echo -e "INFO: getting stack id ... "
    local stack_id=$(git_ref)
    [[ -z "$stack_id" ]] && echo >&2 "ERROR: can't get git ref for unique stack id" && return 1
    echo -e "$stack_id\n"

    echo "INFO: starting swarm stack"
    start_stack "$stack_id" || return 1

    echo "INFO: scaling as needed"
    scale_instances "$stack_id" || rc=1

    echo "INFO: waiting for App A /health to be available"
    [[ $rc -ne 0 ]] || wait_for_service "$stack_id" || rc=1

    echo "INFO: running tests"
    [[ $rc -ne 0 ]] || run_integration_tests "$stack_id" || rc=1

    echo "INFO: killing test stack"
    kill_stack "$stack_id" || rc=1

    return $rc
}

container_script() {
    cat <<'EOF'
#!/bin/sh
export CGO_ENABLED=0
export GOPATH=${GOPATH:-/go} GOBIN=/usr/local/go/bin
export LGOBIN=$GOBIN
export PATH=$GOBIN:$GOPATH/bin:$PATH

# go-junit-report: outputs xunit reports in jenx-consumable format
apk --update --no-cache add git
go get -u github.com/jstemmer/go-junit-report

go test -v | go-junit-report

EOF
}

main
