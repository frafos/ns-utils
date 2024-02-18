#
# Very simple container helpers
#

detect_container_runtime() {
  if [[ -f /usr/bin/podman ]] ; then
    # check if current user is root
    if [[ "${UID}" -eq 0 ]] ; then
      # if user is root, we will just use regular podman
      echo "podman"
    else
      # otherwise we'll use sudo upfront
      echo "sudo-podman"
    fi
  elif [[ -f /usr/bin/systemd-nspawn ]] ; then
    echo "systemd-nspawn"
  elif [[ -f /usr/bin/docker ]] ; then
    echo "docker"
  else
    echo "could not detect container runtime"
    exit -1
  fi
}

# Runtime defaults to auto detection
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-$(detect_container_runtime)}"

pocker_get_pid() {
  if [[ "${CONTAINER_RUNTIME}" == "sudo-podman" ]] ; then
    sudo podman inspect -f '{{.State.Pid}}' $1
  else
    ${CONTAINER_RUNTIME} inspect -f '{{.State.Pid}}' $1
  fi
}

container_pid() {
  case ${CONTAINER_RUNTIME} in
    systemd-nspawn)
      machinectl show -p Leader --value $1
      ;;
    *podman|docker)
      pocker_get_pid $1
      ;;
    *)
      echo "unknown container runtime"
      exit -1
  esac
}

netns_exec() {
  lead_pid=$(container_pid $1) ; shift
  sudo nsenter -n -t ${lead_pid} $@
}

allns_exec() {
  lead_pid=$(container_pid $1) ; shift
  env_vars=
  if [[ "${CONTAINER_RUNTIME}" != "systemd-nspawn" ]] ; then
    env_vars=$(sudo cat /proc/${lead_pid}/environ | xargs -0)
  fi
  sudo nsenter -a -t ${lead_pid} env -i - ${env_vars} $@
}
