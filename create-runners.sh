#!/bin/bash
#
# Launches specified amount of GitHub Actions runners
# in Docker for all repositories (of PAT holder)
# that has any workflows.
#
#   Base image:
#     https://hub.docker.com/r/myoung34/github-runner
#     https://github.com/myoung34/docker-github-actions-runner

# ==================== FUNCTIONS ====================

function get_owner_repo_full_names() {
  local response="$(curl \
    --location \
    --silent \
    --show-error \
    --fail \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GITHUB_PAT}"\
    --header "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user/repos")"

  echo "${response}" | \
  jq -r '
    .[]
    | select(.topics | any(index("self-hosted-runner")))
    | select(.permissions.admin)
    | .full_name
  '
}

function check_repo_has_workflows() {
  local repo_full_name="$1"

  local response="$(curl \
    --location \
    --silent \
    --show-error \
    --fail \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GITHUB_PAT}"\
    --header "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${repo_full_name}/actions/workflows")"

  local total_count="$(echo "${response}" | jq -r '.total_count')"

  if [ $total_count -gt 0 ]; then
    echo true
  else
    echo false
  fi
}

function get_runner_token() {
  local repo_full_name="$1"

  local response="$(curl \
    --location \
    --silent \
    --show-error \
    --fail \
    --request "POST" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GITHUB_PAT}"\
    --header "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${repo_full_name}/actions/runners/registration-token")"

  local runner_token="$(echo "${response}" | jq -r '.token')"

  echo "${runner_token}"
}

function build_runner_image() {
  export BASE_IMAGE_VERSION="$1"
  local runner_image_tag="$2"

  local tmp="$(mktemp)"

  cat Dockerfile | envsubst '${BASE_IMAGE_VERSION}' > "${tmp}"

  docker build \
    --file "${tmp}" \
    --tag "${runner_image_tag}" \
    --target "github-actions-runner" \
    .

  rm -f "${tmp}"
}

function get_runner_image_tag() {
  local base_image_version="$1"
  echo "github-actions-runner:${base_image_version}"
}

function get_base_image_version() {
  if [ -z "$1" ]; then
    echo "latest"
  else
    echo "$1"
  fi
}

function run_runner_containers() {
  local repo_full_name="$1"
  local runner_token="$2"
  local runner_image_tag="$3"
  local quantity="$4"
  local labels="$5"

  if [ -z "${quantity}" ]; then
    quantity=1
  fi

  local repo_name="$(echo "${repo_full_name}" | cut -d "/" -f 2)"

  for runner_index in $(seq -w 01 ${quantity}); do
    local runner_name="runner-${repo_name}-${runner_index}"

    runner_name="${runner_name,,}"

    echo
    echo "Starting ${runner_name}"
    echo

    local container_id="$(docker run \
      --detach \
      --rm \
      --name "${runner_name}" \
      --env REPO_URL="https://github.com/${repo_full_name}" \
      --env RUNNER_NAME="${runner_name}" \
      --env RUNNER_TOKEN="${runner_token}" \
      --env RUNNER_WORKDIR="/tmp/${runner_name}" \
      --env LABELS="${labels}" \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume /tmp/${runner_name}:/tmp/${runner_name} \
      "${runner_image_tag}")"
  done
}

function create_runners() {
  local quantity="$1"
  local labels="$3"

  local base_image_version="$(get_base_image_version "$2")"
  local runner_image_tag="$(get_runner_image_tag "${base_image_version}")"

  build_runner_image "${base_image_version}" "${runner_image_tag}"

  get_owner_repo_full_names | while read repo_full_name; do
    if $(check_repo_has_workflows "${repo_full_name}"); then
      local runner_token="$(get_runner_token "${repo_full_name}")"

      run_runner_containers \
        "${repo_full_name}" \
        "${runner_token}" \
        "${runner_image_tag}" \
        "${quantity}" \
        "${labels}"
    fi
  done
}

function create_runner() {
  local quantity="$1"
  local labels="$3"
  local repo_full_name="$4"

  local base_image_version="$(get_base_image_version "$2")"
  local runner_image_tag="$(get_runner_image_tag "${base_image_version}")"

  build_runner_image "${base_image_version}" "${runner_image_tag}"

  local runner_token="$(get_runner_token "${repo_full_name}")"

  run_runner_containers \
    "${repo_full_name}" \
    "${runner_token}" \
    "${runner_image_tag}" \
    "${quantity}" \
    "${labels}"
}

# ==================== EXECUTION ====================

set -e

quantity=1
base_image="2.303.0-ubuntu-focal"
labels="docker"
repo=""
need_help=false

while [ $# -gt 0 ]; do
  if [ "$1" == "--token" ]; then
    GITHUB_PAT="$2"
    shift
    shift
  elif [ "$1" == "--token-stdin" ]; then
    GITHUB_PAT="$(cat)"
    shift
  elif [ "$1" == "--quantity" ]; then
    quantity="$2"
    shift
    shift
  elif [ "$1" == "--base-image" ]; then
    base_image="$2"
    shift
    shift
  elif [ "$1" == "--labels" ]; then
    labels="$2"
    shift
    shift
  elif [ "$1" == "--repo" ]; then
    repo="$2"
    shift
    shift
  elif [ "$1" == "--help" ]; then
    need_help=true
    shift
  fi
done

if $need_help; then
  echo
  echo "  Launches specified amount of GitHub Actions runners"
  echo "  in Docker for all repositories (of PAT holder)"
  echo "  that has any workflows."
  echo
  echo "    Environment:"
  echo "      GITHUB_PAT       GitHub Personal Access Token."
  echo
  echo "    Parameters:"
  echo "      --token          GitHub Personal Access Token."
  echo "      --token-stdin    Pass GitHub Personal Access Token via stdin."
  echo "      --base-image     Version of base image."
  echo "      --quantity       Quantity of runners per repository."
  echo "      --labels         Labels for all runners."
  echo "      --repo           Single exact repo, in format \`owner/repo-name\`."
  echo "      --help           Prints this message."
  echo

  exit 0
fi

export GITHUB_PAT

if [ -z "${repo}" ]; then
  create_runners \
    "${quantity}" \
    "${base_image}" \
    "${labels}"
else
  create_runner \
    "${quantity}" \
    "${base_image}" \
    "${labels}" \
    "${repo}"
fi

exit 0
