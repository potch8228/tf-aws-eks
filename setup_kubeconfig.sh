#!/bin/env bash

terraform output -json kubeconfig | jq -r . > ~/.kube/config
