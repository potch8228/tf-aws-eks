# Note: ALL Kubernetes directly related resources (= ones not aws resources with exception)
#       needs AWS EKS cluster to be built. But cross module dependency is not
#       easy to create because of dependency providers.
#       Need to use null_resource.dependency to wait and organize build/destruction
#       order.

# ======================== Setup main application namespace ===================
# mainly intended for Fargate profile
resource "kubernetes_namespace" "app_ns" {
  metadata {
    name = format("%s-apps", replace(var.app_name, "_", "-"))
  }

  depends_on = [null_resource.dependency]
}

# ============================ Setup autoscaler ================================
resource "aws_iam_policy" "helm_cluster_autoscaler_iam_policy" {
  name   = format("%s_eks_cluster_autoscaler_IAMPolicy", var.app_name)
  policy = file("${path.module}/k8s_configs/autoscaler_iam_policy.json")
}

data "aws_iam_role" "iam_role_eks_nodes" {
  name       = format("%s_iam_role_eks_nodes", var.app_name)
  depends_on = [null_resource.dependency]
}

resource "aws_iam_role_policy_attachment" "iam_role_attach-eks_cluster_autoscaler_IAMPolicy" {
  policy_arn = aws_iam_policy.helm_cluster_autoscaler_iam_policy.arn
  role       = data.aws_iam_role.iam_role_eks_nodes.name
}

resource "helm_release" "helm_cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.3.0"

  namespace = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = data.aws_eks_cluster.eks_cluster.name
  }

  set {
    name  = "awsRegion"
    value = "ap-northeast-1"
  }

  depends_on = [null_resource.dependency]
}

# ============================ Setup metrics server ============================
resource "helm_release" "heml_metrics_server" {
  name       = "metrics-server"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = "5.3.3"

  namespace = "kube-system"

  depends_on = [null_resource.dependency]
}

# ======================== Setup Prometheus monitoring ========================
resource "helm_release" "helm_prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "13.0.1"

  namespace        = "prometheus"
  create_namespace = true

  set {
    name  = "alertmanager.persistentVolume.storageClass"
    value = "gp2"
  }

  set {
    name  = "server.persistentVolume.storageClass"
    value = "gp2"
  }

  depends_on = [null_resource.dependency]
}
# ======================== Setup AWS ALB Ingress Controller ====================
resource "aws_iam_policy" "alb_iam_policy" {
  name   = format("%s_AWSLoadBalancerControllerIAMPolicy", var.app_name)
  policy = file("${path.module}/k8s_configs/alb_ingress_iam_policy_v2_1_0.json")
}

resource "aws_iam_policy" "alb_iam_policy_additional" {
  name   = format("%s_AWSLoadBalancerControllerAdditionalIAMPolicy", var.app_name)
  policy = file("${path.module}/k8s_configs/alb_ingress_iam_policy_v1_to_v2_additional.json")
}

locals {
  eks_oidc     = trimprefix(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://")
  iam_arn_base = regex("arn:aws:iam::[[:alnum:]]+", data.aws_eks_cluster.eks_cluster.role_arn)
}

resource "aws_iam_role" "iam_role_alb_ingress" {
  name = format("%s_AmazonEKSLoadBalancerControllerRole", var.app_name)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = format("%s:oidc-provider/%s", local.iam_arn_base, local.eks_oidc)
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            format("%s:sub", local.eks_oidc) = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_attach-AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.alb_iam_policy.arn
  role       = aws_iam_role.iam_role_alb_ingress.name
}

resource "aws_iam_role_policy_attachment" "iam_role_attach-AWSLoadBalancerControllerAdditionalIAMPolicy" {
  policy_arn = aws_iam_policy.alb_iam_policy_additional.arn
  role       = aws_iam_role.iam_role_alb_ingress.name
}

resource "kubernetes_service_account" "alb_service_account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component" = "controller",
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.iam_role_alb_ingress.arn
    }
  }

  automount_service_account_token = true

  depends_on = [
    null_resource.dependency,
    aws_iam_policy.alb_iam_policy
  ]
}

resource "kubectl_manifest" "alb_crds" {
  yaml_body = file("${path.module}/k8s_configs/alb_ingress_crds_v0_0_39.yaml")
  depends_on = [
    null_resource.dependency,
    kubernetes_service_account.alb_service_account
  ]
}

resource "helm_release" "helm_aws_alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.1.1"

  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.eks_cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_service_account.metadata[0].name
  }

  set {
    name  = "region"
    value = "ap-northeast-1"
  }

  set {
    name  = "vpcId"
    value = data.aws_eks_cluster.eks_cluster.vpc_config[0].vpc_id
  }

  depends_on = [
    null_resource.dependency,
    kubectl_manifest.alb_crds
  ]
}
