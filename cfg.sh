# vim: et sr sw=2 ts=2 smartindent:
#
# This file should remain at project root.
#
# ... common cfg vals
#
APP="simple-spark-api"

# ... either user defined, or defaults to dir with this file in it.
PROJ_ROOT_DIR="${PROJ_ROOT_DIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )}"

GIT_SHA_LEN="8" # preferred length of git sha1s
GIT="git --no-pager"

CURL_IMAGE="byrnedo/alpine-curl:latest" # to curl containers on private test stack docker net
GOLANG_IMAGE="golang:1.11.4-alpine3.8"  # for running integration tests
MVN_IMAGE="maven:3-jdk-8-alpine"        # for building app

