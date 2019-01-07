#!/bin/bash
# vim: et sr sw=4 ts=4 smartindent:

# source cfg and libs first to take advantage of common vars and funcs.
! . cfg.sh && echo >&2 "ERROR: could not source common vars file" && exit 1
! . libs.sh && echo >&2 "ERROR: could not source common libs file" && exit 1

ARTEFACT="${APP}-*-jar-with-dependencies.jar"
HOST_M2_DIR="${HOST_M2_DIR:-$HOME/projects/.m2}"

# ... get app version from pom.xml for potential tagging of docker image
app_version() {
    docker run -t --rm --name get_version-$(date +'%Y%m%d%H%M%S') \
        -v $HOST_M2_DIR:/root/.m2 \
        -v $PROJ_ROOT_DIR:/usr/src/mymaven `# map this git repo root` \
        -w /usr/src/mymaven $MVN_IMAGE \
            mvn -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec
}

mvn_build() {
    rm -rf ./target 2>/dev/null

    docker run -it --rm --name app-a-$(date +'%Y%m%d%H%M%S') \
        -v $HOST_M2_DIR:/root/.m2 \
        -v $PROJ_ROOT_DIR:/usr/src/mymaven `# map this git repo root` \
        -w /usr/src/mymaven $MVN_IMAGE \
            mvn -T 1C clean package || return 1

    cp ./target/$ARTEFACT .
    rm -rf ./target 2>/dev/null || true
}

docker_build() {
    local git_ref="$1"
    local version="$2"
    local labels="$3"
    local rc=0
    docker build --force-rm $labels -t $APP:${git_ref} .
}

prep_env() { docker pull $MVN_IMAGE ; }

labels() {
    local version="$1"
    gu=$(git_uri) || return 1
    gs=$(git_sha) || return 1
    gb=$(git_branch) || return 1
    gt=$(git describe --exact-match --tags 2>/dev/null || echo "no-git-tag")
    bb=$(built_by | sed -e 's/ \+/_/g') || return 1

    cat<<EOM
    --label build=$(date +'%Y%m%d%H%M%S')
    --label $APP.version=$version
    --label $APP.build_git_uri=$gu
    --label $APP.build_git_sha=$gs
    --label $APP.build_git_branch=$gb
    --label $APP.build_git_tag=$gt
    --label $APP.built_by=$bb
EOM
}

main(){
    local rc=0
    ! prep_env && echo "ERROR: unable to prep env" && return 1

    echo "BUILDING $APP app ..."
    echo "... configuring labels for docker image"
    local git_ref=$(git_ref)
    local version=$(app_version)
    local labels=$(labels $version) || return 1

    echo "VERSION: $version"
    echo "GIT REF: $git_ref"
    echo "LABELS: $labels"

    mvn_build || return 1

    docker_build "$git_ref" "$version" "$labels" || rc=1
    rm -rf $ARTEFACT 2>/dev/null

    return $rc
}

main
