resource "aws_security_group" "eks_cluster_sg" {
  name        = format("%s_eks_cluster_sg", var.app_name)
  description = "EKS cluster communication with worker nodes created by terraform"
  vpc_id      = data.aws_vpc.vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = format("%s_eks_cluster_sg", var.app_name)
  }
}

resource "aws_security_group_rule" "eks_cluster_ingress_workstation_https_sg" {
  cidr_blocks       = [local.workstation_external_cidr]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_cluster_sg.id
  to_port           = 443
  type              = "ingress"
}
