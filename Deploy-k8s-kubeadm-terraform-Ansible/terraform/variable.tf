variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

#variable "private_subnet_cidr" {
#  description = "CIDR block for the private subnet."
#  type        = string
#  default     = "10.0.2.0/24"
#}

variable "availability_zone" {
  description = "AWS availability zone."
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "worker_nodes_instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "m5.xlarge"
}

variable "ansible_instance_type" {
  description = "Instance type for the Ansible control machine."
  type        = string
  default     = "t3.medium"
}

#variable "bastion_instance_type" {
#  description = "Instance type for the bastion host."
#  type        = string
#  default     = "t3.medium"
#}

variable "my_public_ip" {
  description = "Your public IP address with CIDR notation (e.g., 203.0.113.1/32). Used to restrict SSH access."
  type        = string
}

variable "ubuntu_ami" {
  description = "Ubuntu Server 24.04 LTS"
  type        = string
  default = "ami-0866a3c8686eaeeba"
}

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 3
}

variable "key_pair_name" {
  description = "Name of the AWS key pair."
  type        = string
  #default = "ansible-key"
}