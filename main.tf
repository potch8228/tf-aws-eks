provider "aws" {
  region = "ap-northeast-1"
}

module "vpc_networking" {
  source = "./tf_aws/vpc_networking"

  app_name = var.app_name
}

module "eks" {
  source = "./tf_aws/eks"

  app_name = var.app_name

  depends_on = [
    module.vpc_networking
  ]
}
