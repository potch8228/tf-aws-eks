resource "aws_security_group" "vpc_all_access_sg" {
  name        = format("%s_vpc_all_access_sg", var.app_name)
  description = "Security Group for All Access Allowed (for testing purpose) created by terraform"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = format("%s_vpc_all_access_sg", var.app_name)
  }
}

resource "aws_security_group" "vpc_ssh_all_access_sg" {
  name        = format("%s_vpc_ssh_all_access_sg", var.app_name)
  description = "Security Group for SSH Access from All Allowed created by terraform"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = format("%s_vpc_ssh_all_access_sg", var.app_name)
  }
}
