output "ansible_control_private_ip" {
  description = "Private IP address of the Ansible control machine"
  value       = aws_instance.ansible_control.private_ip
}

output "ansible_control_public_ip" {
  description = "Private IP address of the Ansible control machine"
  value       = aws_instance.ansible_control.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP address of the Kubernetes control plane node"
  value       = aws_instance.control_plane.private_ip
}

output "control_plane_public_ip" {
  description = "Private IP address of the Kubernetes control plane node"
  value       = aws_instance.control_plane.public_ip
}

output "worker_nodes_private_ips" {
  description = "Private IP addresses of the Kubernetes worker nodes"
  value       = [for instance in aws_instance.worker_nodes : instance.private_ip]
}

output "worker_nodes_public_ips" {
  description = "Private IP addresses of the Kubernetes worker nodes"
  value       = [for instance in aws_instance.worker_nodes : instance.public_ip]
}
