data "aws_vpc" "vpc" {
  tags = {
    Name = format("%s_vpc", var.app_name)
  }
}

data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    Tier = "Private"
  }
}

data "aws_subnet_ids" "public_subnets" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    Tier = "Public"
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = format("%s_eks_cluster", var.app_name)
  role_arn = aws_iam_role.iam_role_eks_cluster.arn

  vpc_config {
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    subnet_ids              = data.aws_subnet_ids.subnets.ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  version = "1.18"

  tags = {
    Name = format("%s_eks_cluster", var.app_name)
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEKSVPCResourceController,
  ]
}

data "tls_certificate" "eks_cluster_tls_cert" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "iam_oidc_eks_cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_tls_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "eks_cluster_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.iam_oidc_eks_cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.iam_oidc_eks_cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_cluster_iam_role" {
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role_policy.json
  name               = format("%s_eks_cluster_iam_role", var.app_name)
}

# ======= EKS Nodes for Kubernetes Pods for core functionality management =====
resource "aws_eks_node_group" "eks_worker_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = format("%s_eks_worker_nodes", var.app_name)
  node_role_arn   = aws_iam_role.iam_role_eks_nodes.arn
  subnet_ids      = data.aws_subnet_ids.private_subnets.ids

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 2
  }

  ami_type       = "AL2_x86_64"
  instance_types = ["t3.medium"]

  tags = {
    Name = format("%s_eks_worker_nodes", var.app_name)
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# =========== EKS Fargate profile for Application Kubernetes Pods ==============
resource "aws_eks_fargate_profile" "eks_fargate_app_nodes" {
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = format("%s_eks_fargate_app_nodes", var.app_name)
  pod_execution_role_arn = aws_iam_role.iam_role_eks_fargate.arn
  subnet_ids             = data.aws_subnet_ids.private_subnets.ids

  selector {
    namespace = format("%s-apps", replace(var.app_name, "_", "-"))
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEKSFargatePodExecutionRolePolicy,
  ]

  tags = {
    Name = format("%s_eks_fargate_app_nodes", var.app_name)
  }
}
