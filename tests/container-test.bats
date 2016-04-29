#!/usr/bin/env bats

# dependencies of this test: bats, ansible, docker, sed, grep
# control machine requirements for playbook under test: ???

readonly container_name=ansible-virt-host

container_startup() {
  local _container_name=$1
  local _container_image=$2
  local _ssh_host=localhost
  local _ssh_port=5555
  local _ssh_public_key=~/.ssh/id_rsa.pub
  local _container_id
  container_id=(docker run --name $_container_name -d -p $_ssh_port:22 \
    -e USERNAME=test -e AUTHORIZED_KEYS="$(< $_ssh_public_key)" -v $_container_name:/var/cache/dnf $_container_image)
  ansible localhost -m wait_for -a "port=$_ssh_port host=$_ssh_host search_regex=OpenSSH delay=10"
  printf 'container %s %s %s' $_ssh_host $_ssh_port $_container_id
}

container_cleanup() {
  local _container_id=${1[3]}
  docker stop $_container_id > /dev/null
  docker rm $_container_id > /dev/null
}

container_inventory() {
  local _host=${1[0]}
  local _ssh_host=${1[1]}
  local _ssh_port=${1[2]}
  printf '%s ansible_host=%s ansible_port=%s\n' $_host $_ssh_host $_ssh_port
}

container_exec() {
  ansible container -i hosts -u test -m shell -a "$*" | tail -n +2
}

container_exec_sudo() {
  ansible container -i hosts -u test -s -m shell -a "$*" | tail -n +2
}

container_dnf_conf() {
  local _name=$1
  local _value=$2
  ansible container -i hosts -u test -s -m lineinfile -a \
    "dest=/etc/dnf/dnf.conf regexp='^$_name=\S+$' line='$_name=$_value'"
}

setup() {
  container=($(container_startup $container_name 'alzadude/fedora-ansible-test:23'))
  container_dnf_conf keepcache 1
  container_dnf_conf metadata_timer_sync 0
}

@test "Role can be applied to container" {
  ansible-playbook -i "$(container_inventory $container)," test.yml
}

@test "Role is idempotent" {
  run ansible-playbook -i hosts test.yml
  run ansible-playbook -i hosts test.yml
  [[ $output =~ changed=0.*unreachable=0.*failed=0 ]]
}

teardown() {
  container_cleanup $container
}
