# Namespace Utils

This is a very small set of shell functions that help running commands
in container namespaces.

## Installation

Just download [ns-utils.sh](ns-utils.sh) to your home directory and `source` it.

``` shell
git clone https://gitlab.frafos.net/Coeffic/ns-utils
source ns-utils/ns-utils.sh
```

## Usage

First of all, it is important if the correct container runtime has been detected
with `detect_container_runtime`:

``` shell
frafos@testhost:~$ detect_container_runtime
sudo-podman
```

The supported runtimes are:
- `sudo-podman`: podman containers run as `root` user.
- `podman`: podman container run as current user.
- `systemd-nspawn`: well, the name says it all.

In case the runtime is not detected correctly (you have more than one installed),
just define `CONTAINER_RUNTIME` accordingly:

``` shell
export CONTAINER_RUNTIME=systemd-nspawn
```

### `netns_exec`

This function allows to execute a command in the container's **network namespace**, while
keeping all other namespaces untouched.

This is particularily useful to run commands which are not available in the
container image.

``` shell
frafos@testhost:~$ netns_exec ldap ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 9e:ab:72:6c:c1:e7 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.89.0.10/24 brd 10.89.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::9cab:72ff:fe6c:c1e7/64 scope link 
       valid_lft forever preferred_lft forever
```


### `allns_exec`

This function allows to execute a command in the container's namespaces.

On most container runtimes it is mostly equivalent to the `exec` command, except
for `systemd-nspawn`, which does not have a real `exec` command.

This is particularily useful to deal with `systemd-nspawn`, which has some deficiencies when
executing things inside a container:
- `machinectl shell` starts a full user session and does not propagate exit codes. Besides, it
  does not even work with container that do not boot with `systemd`.
- `systemd-run` is able to propagate exit codes, but does not work either with containers that
  do not boot with `systemd`. Another downside is that it insists on start the command run
  as a separate unit inside that container, which has other consequences.

``` shell
frafos@testhost:~$ machinectl list
MACHINE  CLASS     SERVICE        OS     VERSION ADDRESSES
test-sbc container systemd-nspawn debian 11      -        

1 machines listed.

frafos@testhost:~$ allns_exec test-sbc bash -l -c env
PWD=/
SHLVL=0
TMOUT=600
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
_=/usr/bin/env
```

**Please note** that `allns_exec` will reset the environment variables in the command started.
If `systemd-nspawn` as a runtime, the environment will be left empty, whereby it will be populated
with the environment of the container's `PID 1` for all other runtimes.
