#!/usr/bin/env bash

set -eu

terraform output -json kubeconfig | jq -r . > ~/.kube/config
