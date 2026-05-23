output "master_instance_profile" { value = aws_iam_instance_profile.master.name }
output "worker_instance_profile" { value = aws_iam_instance_profile.worker.name }
output "master_role_arn"         { value = aws_iam_role.master.arn }
output "worker_role_arn"         { value = aws_iam_role.worker.arn }
