# Security Group for Bastion Host
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Security group for Kubernetes cluster nodes and Ansible control server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH from my public IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.my_public_ip]
  }
    ingress {
    description      = "SSH from my public IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Kubernetes API access from within the VPC"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public.cidr_block, var.my_public_ip]
}

  ingress {
    description = "Allow Kubernetes API access from within the VPC"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

  ingress {
    description = "Allow all traffic within the security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}


##=====================================
# Security Group for Private Instances
#resource "aws_security_group" "private_sg" {
#  name        = "private-sg"
#  description = "Security group for private instances"
#  vpc_id      = aws_vpc.main.id

#  ingress {
#    description      = "SSH from bastion host"
#    from_port        = 22
#    to_port          = 22
#    protocol         = "tcp"
#    security_groups  = [aws_security_group.public_sg.id]
#  }

#  ingress {
#    description = "All traffic within the private subnet"
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = [var.private_subnet_cidr]
#  }

#  egress {
#    description = "Allow all outbound traffic"
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#  }

#  tags = {
#    Name = "private-sg"
#  }
#}
