terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.21.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "1.13.3"
    }


    helm = {
      source  = "hashicorp/helm"
      version = "2.0.1"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.9.4"
    }
  }
}
