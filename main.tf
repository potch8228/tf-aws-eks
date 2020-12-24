terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.21.0"
    }
  }
}

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

module "k8s" {
  source = "./tf_aws/k8s"

  app_name = var.app_name

  # dependency trigger
  eks_cluster_name = module.eks.eks_cluster_name
}
