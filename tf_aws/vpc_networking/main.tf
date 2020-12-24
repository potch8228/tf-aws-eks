# Basic Networking Environment (a.k.a Sandbox)
# 65534 hosts can be hosted in: 10.0.0.1 - 10.0.255.254
resource "aws_vpc" "vpc" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true

  tags = {
    Name = format("%s_vpc", var.app_name)
  }
}

# ================== Subnets across the availability_zones  ===================

# Create a subnet to launch our instances into
# ap-northeast-1 has no "AZ-B" (as of 2020/12)
# Split VPC subnet into 6, to have both public and private subnets and
# the redundancy

# Because the mask bit is the power of 2, 2 subnets are left unused
# Each subnet will have 8190 hosts

resource "aws_subnet" "sub_public_a" {
  vpc_id = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/19"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                                                         = format("%s_sub_public_a", var.app_name)
    Tier                                                         = "Public"
    format("kubernetes.io/cluster/%s_eks_cluster", var.app_name) = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "sub_public_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.32.0/19"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name                                                         = format("%s_sub_public_c", var.app_name)
    Tier                                                         = "Public"
    format("kubernetes.io/cluster/%s_eks_cluster", var.app_name) = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "sub_public_d" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = true

  tags = {
    Name                                                         = format("%s_sub_public_d", var.app_name)
    Tier                                                         = "Public"
    format("kubernetes.io/cluster/%s_eks_cluster", var.app_name) = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "sub_private_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name                                                         = format("%s_sub_private_a", var.app_name)
    Tier                                                         = "Private"
    format("kubernetes.io/cluster/%s_eks_cluster", var.app_name) = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "sub_private_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.128.0/19"
  availability_zone       = "ap-northeast-1c"

  tags = {
    Name                                                         = format("%s_sub_private_c", var.app_name)
    Tier                                                         = "Private"
    format("kubernetes.io/cluster/%s_eks_cluster", var.app_name) = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "sub_private_d" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.160.0/19"
  availability_zone       = "ap-northeast-1d"

  tags = {
    Name                                                         = format("%s_sub_private_d", var.app_name)
    Tier                                                         = "Private"
    format("kubernetes.io/cluster/%s_eks_cluster", var.app_name) = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# =============================================================================

# ============================ Network routings  ==============================

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = format("%s_igw", var.app_name)
  }
}

# ElasticIP (VPC's Global IP address)
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = format("%s_nat_eip", var.app_name)
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.sub_public_a.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = format("%s_nat", var.app_name)
  }
}

resource "aws_route_table" "rt_table_public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("%s_rt_table_public", var.app_name)
  }
}

resource "aws_route_table" "rt_table_private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("%s_rt_table_private", var.app_name)
  }
}

# Grant the VPC internet access
resource "aws_route" "rt_internet_access" {
  route_table_id         = aws_route_table.rt_table_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "rt_nat_access" {
  route_table_id         = aws_route_table.rt_table_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "rt_assoc_public_a" {
  subnet_id      = aws_subnet.sub_public_a.id
  route_table_id = aws_route_table.rt_table_public.id
}

resource "aws_route_table_association" "rt_assoc_public_c" {
  subnet_id      = aws_subnet.sub_public_c.id
  route_table_id = aws_route_table.rt_table_public.id
}

resource "aws_route_table_association" "rt_assoc_public_d" {
  subnet_id      = aws_subnet.sub_public_d.id
  route_table_id = aws_route_table.rt_table_public.id
}

resource "aws_route_table_association" "rt_assoc_private_a" {
  subnet_id      = aws_subnet.sub_private_a.id
  route_table_id = aws_route_table.rt_table_private.id
}

resource "aws_route_table_association" "rt_assoc_private_c" {
  subnet_id      = aws_subnet.sub_private_c.id
  route_table_id = aws_route_table.rt_table_private.id
}

resource "aws_route_table_association" "rt_assoc_private_d" {
  subnet_id      = aws_subnet.sub_private_d.id
  route_table_id = aws_route_table.rt_table_private.id
}

# =============================================================================

# ============================== Network ACL  =================================

resource "aws_network_acl" "net_acl_public" {
  vpc_id = aws_vpc.vpc.id

  subnet_ids = [
    aws_subnet.sub_public_a.id,
    aws_subnet.sub_public_c.id,
    aws_subnet.sub_public_d.id,
    aws_subnet.sub_private_a.id,
    aws_subnet.sub_private_c.id,
    aws_subnet.sub_private_d.id
  ]

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no         = 101
    protocol        = "-1"
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no         = 101
    protocol        = "-1"
    action          = "allow"
    ipv6_cidr_block = "::/0"
    from_port       = 0
    to_port         = 0
  }

  tags = {
    Name = format("%s_net_acl_public", var.app_name)
  }
}

# =============================================================================
