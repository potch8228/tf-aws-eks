# ============================ Module dependency trigger =======================
resource "null_resource" "dependency" {
  triggers = {
    dependency_id = var.eks_cluster_name
  }
}
# ==============================================================================

data "aws_eks_cluster" "eks_cluster" {
  name       = var.eks_cluster_name
  depends_on = [null_resource.dependency]
}

data "aws_eks_cluster_auth" "eks_auth" {
  name       = var.eks_cluster_name
  depends_on = [null_resource.dependency]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks_auth.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
  load_config_file       = false
}
