#!/bin/bash

export ANSIBLE_HOST_KEY_CHECKING=False

if [ $# -lt 2 ]; then
    echo "Usage: $0 inventory playbook-1.yml [playbook-2.yml ... ]"
    echo "Example: $0 inventory_dev web.yml"
    exit 1
fi

cd `dirname $0` &&
ansible-playbook -v -e "inventory=$1" -i $1 ${@:2}
