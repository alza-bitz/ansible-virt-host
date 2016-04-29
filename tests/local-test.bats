#!/usr/bin/env bats

@test "Role syntax" {
    ansible-playbook -i hosts test.yml --syntax-check
}
