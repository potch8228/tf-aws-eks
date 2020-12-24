#!/usr/bin/env bash

set -eu

if [ ! -f "~/.kube/config" ]; then
  source ./setup_kubeconfig.sh
fi

if [ ! -f "./k8s/terraform.tfvars" ]; then
  echo "could not locate Terraform vars file"
  exit 1
fi

terraform plan -out=k8s.out -var-file=./k8s/terraform.tfvars ./k8s/
terraform apply -out=k8s.out  -var-file=./k8s/terraform.tfvars ./k8s/
