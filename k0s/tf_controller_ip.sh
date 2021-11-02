#!/bin/sh

terraform show -json | jq -rs '.[].values.root_module.resources[0].values.ip_address'
