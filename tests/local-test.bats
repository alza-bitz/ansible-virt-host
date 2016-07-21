#!/usr/bin/env bats

load 'bats-ansible/load'

@test "Role syntax" {
    ansible-playbook ${BATS_TEST_DIRNAME}/test.yml --syntax-check
}
