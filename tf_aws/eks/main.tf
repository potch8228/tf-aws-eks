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

# EKS Nodes for Kubernetes Pods for core functionality management
# ... but this can be replaced with Fargate profile below...
# resource "aws_eks_node_group" "eks_worker_nodes" {
#   cluster_name    = aws_eks_cluster.eks_cluster.name
#   node_group_name = format("%s_eks_worker_nodes", var.app_name)
#   node_role_arn   = aws_iam_role.iam_role_eks_nodes.arn
#   subnet_ids      = data.aws_subnet_ids.private_subnets.ids
# 
#   scaling_config {
#     desired_size = 1
#     max_size     = 1
#     min_size     = 1
#   }
# 
#   ami_type       = "AL2_ARM_64"
#   instance_types = ["c6g.medium"]
# 
#   tags = {
#     Name = format("%s_eks_worker_nodes", var.app_name)
#   }
# 
#   depends_on = [
#     aws_eks_cluster.eks_cluster,
#     aws_iam_role_policy_attachment.iam_role_attach-AmazonEKSWorkerNodePolicy,
#     aws_iam_role_policy_attachment.iam_role_attach-AmazonEKS_CNI_Policy,
#     aws_iam_role_policy_attachment.iam_role_attach-AmazonEC2ContainerRegistryReadOnly,
#   ]
# 
#   lifecycle {
#     ignore_changes = [scaling_config[0].desired_size]
#   }
# }

resource "aws_eks_fargate_profile" "eks_fargate_system_coredns_nodes" {
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = format("%s_eks_fargate_system_coredns_nodes", var.app_name)
  pod_execution_role_arn = aws_iam_role.iam_role_eks_fargate.arn
  subnet_ids             = data.aws_subnet_ids.private_subnets.ids

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.iam_role_attach-AmazonEKSFargatePodExecutionRolePolicy,
  ]

  tags = {
    Name = format("%s_eks_fargate_system_coredns_nodes", var.app_name)
  }
}

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
