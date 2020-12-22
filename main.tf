provider "aws" {
  region = "ap-northeast-1"
}

module "vpc_networking" {
  source = "./tf_aws/vpc_networking"

  app_name = var.app_name
}
