# vim: et sr sw=2 ts=2 smartindent:
#
# ... common functions
#
git_sha(){
    $GIT rev-parse --short=${GIT_SHA_LEN} --verify HEAD
}

git_ref() {
    $GIT describe --exact-match --tags 2>/dev/null \
    || $GIT rev-parse --short=8 --verify HEAD
}

git_uri(){
    $GIT config remote.origin.url || echo 'no-remote'
}

git_branch(){
    r=$($GIT rev-parse --abbrev-ref HEAD)
    [[ -z "$r" ]] && echo "ERROR: no rev to parse when finding branch? " >&2 && return 1
    [[ "$r" == "HEAD" ]] && r="from-a-tag"
    echo "$r"
}

# ... will use (in order of preference) ci/cd job url || aws user id || git user
built_by() {
    local user="--UNKNOWN--"
    if [[ ! -z "${BUILD_URL}" ]]; then
        user="${BUILD_URL}"
    elif [[ ! -z "${AWS_PROFILE}" ]] || [[ ! -z "${AWS_ACCESS_KEY_ID}" ]]; then
        user="$(aws iam get-user --query 'User.UserName' --output text)@$HOSTNAME"
    else
        user="$($GIT config --get user.name)@$HOSTNAME"
    fi
    echo "$user"
}

