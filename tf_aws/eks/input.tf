# from https://github.com/hashicorp/terraform-provider-aws/blob/master/examples/eks-getting-started/workstation-external-ip.tf

data "http" "workstation_external_cidr" {
  url = "http://ipv4.icanhazip.com"
}

locals {
  workstation_external_cidr = format("%s/32", chomp(data.http.workstation_external_cidr.body))
}
