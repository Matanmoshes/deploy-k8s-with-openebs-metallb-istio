# Bastion Host
#resource "aws_instance" "bastion" {
#  ami                    = var.ubuntu_ami
#  instance_type          = var.bastion_instance_type
#  subnet_id              = aws_subnet.public.id
#  vpc_security_group_ids = [aws_security_group.public_sg.id]
#  key_name               = var.key_pair_name
#
#  tags = {
#    Name = "bastion-host"
#  }
#}

# Elastic IP for Bastion Host
#resource "aws_eip" "bastion_eip" {
#  instance = aws_instance.bastion.id
#  domain   = "vpc"

#  depends_on = [aws_internet_gateway.gw]

#  tags = {
#    Name = "bastion-eip"
#  }
#}

# Ansible Control Machine
resource "aws_instance" "ansible_control" {
  ami                    = var.ubuntu_ami
  instance_type          = var.ansible_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = var.key_pair_name
  user_data = file("${path.module}/ansible-setup.yaml")

  tags = {
    Name = "ansible-control"
  }
}

# Kubernetes Control Plane Node
resource "aws_instance" "control_plane" {
  ami                    = var.ubuntu_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = var.key_pair_name

    # Increase root volume size to 30GB
  root_block_device {
    volume_size           = 20          # Size in GB
    volume_type           = "gp2"       # General Purpose SSD
    delete_on_termination = true
  }

  tags = {
    Name = "control-plane"
  }
}

# Kubernetes Worker Nodes
resource "aws_instance" "worker_nodes" {
  count                  = var.worker_count
  ami                    = var.ubuntu_ami
  instance_type          = var.worker_nodes_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = var.key_pair_name

    # Increase root volume size to 30GB
  root_block_device {
    volume_size           = 20          # Size in GB
    volume_type           = "gp2"       # General Purpose SSD
    delete_on_termination = true
  }

  # Add an additional EBS volume for Mayastor
  ebs_block_device {
    device_name           = "/dev/sdf"  # Adjust based on your needs
    volume_size           = 20          # Size in GB (minimum recommended for Mayastor)
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name = "worker-node-${count.index + 1}"
  }
}
