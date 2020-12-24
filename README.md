# AWS EKS cluster builder

## What will be created?
  - AWS EKS cluster
    - Node Group for Pods controlling/monitoring deployments
      - Metrics Server
      - Prometheus
      - cluster autoscaler
      - AWS Application LoadBalancer Ingress Controller
    - Fargate Profile for main application use
    - auxiliary IAM settings

## Caution
  - AWS region is targeted at `ap-northeast-1` = Tokyo (and hardcoded for some)
  - RBAC / IAM are at very least setting; need to add extra modifications to suit your requirements
  - Auto Scaling, LoadBalancer features are not tested enough
  - Logging for ether cluster or nodes or pods are not implemented yet

## Tools Required
  - Terraform v0.14
  - kubectl
    - (best to have) eksctl
  - awscli
  - jq

## Usage
### Prerequisite
  - Setup the AWS CLI to set the AWS credential to control AWS services

### Right after cloning repository
- Prepare `terraform.tfvars` file in the root directory
  - Should contains 'app_name = "<app_infra_name>"' variable data
- Execute commands below

```
terraform init
terraform apply # builds EKS cluster
```

### Each time configuration is changed
```
terraform plan
terraform apply
```

### Prepare kubectl to control Kubernetes on EKS
```
# if no kubectl config exists
mkdir ~/.kube

./bin/setup_kubeconfig.sh
```

- In case the command above failed, do following:
  - `terraform output -json kubeconfig | jq -r . > ~/.kube/config`

## Tips about terraform
- How done Terraform keep track of configuration states?
  - Terraform uses `terraform.tfstate<.backup>` file to keep track
    - In another word, if `terraform.tfstate` file were lost, Terraform will try creating exactly the same configuration again (but will fail because of duplication)
    - See https://www.terraform.io/docs/backends/state.html
      - https://www.terraform.io/docs/configuration/blocks/backends/index.html

## License
WTFPL http://www.wtfpl.net/about/
