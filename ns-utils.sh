#
# Very simple container helpers
#

detect_container_runtime() (
  has_cmd() {
    command -v $1 2>&1 > /dev/null
  }

  if has_cmd podman ; then
    # check if current user is root
    if [[ "${UID}" -eq 0 ]] ; then
      # if user is root, we will just use regular podman
      echo "podman"
    else
      # otherwise we'll use sudo upfront
      echo "sudo-podman"
    fi
  elif has_cmd systemd-nspawn && has_cmd machinectl ; then
    echo "systemd-nspawn"
  elif has_cmd docker ; then
    echo "docker"
  elif has_cmd nerdctl ; then
    echo "nerdctl"
  else
    echo "could not detect container runtime"
    exit -1
  fi
)

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
    *podman|docker|nerdctl)
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

local_exec() {
  lead_pid=$(container_pid $1) ; shift
  exec_bin=$(readlink -f $(type -P $1)) ; shift
  sudo nsenter -m -t ${lead_pid} --wd=$(dirname ${exec_bin}) ./$(basename ${exec_bin}) $@
}
