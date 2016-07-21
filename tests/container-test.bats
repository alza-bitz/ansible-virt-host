#!/usr/bin/env bats

# dependencies of this test: bats, ansible, docker, sed, grep
# control machine requirements for playbook under test: ???

load 'bats-ansible/load'

setup() {
  container=$(container_startup fedora)
  hosts=$(tmp_file $(container_inventory $container))
  container_dnf_conf $container keepcache 1
  container_dnf_conf $container metadata_timer_sync 0
}

@test "Role can be applied to container" {
  ansible-playbook -i $hosts ${BATS_TEST_DIRNAME}/test.yml
}

@test "Role is idempotent" {
  run ansible-playbook -i $hosts ${BATS_TEST_DIRNAME}/test.yml
  run ansible-playbook -i $hosts ${BATS_TEST_DIRNAME}/test.yml
  [[ $output =~ changed=0.*unreachable=0.*failed=0 ]]
}

teardown() {
  container_cleanup
}
