output "bastion_public_ip"   { value = aws_instance.bastion.public_ip }
output "bootstrap_public_ip" { value = aws_instance.bootstrap.public_ip }
output "master_private_ips"  { value = aws_instance.master[*].private_ip }
output "master_instance_ids" { value = aws_instance.master[*].id }
output "bootstrap_instance_id" { value = aws_instance.bootstrap.id }
