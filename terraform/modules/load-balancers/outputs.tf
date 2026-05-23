output "api_nlb_ext_dns_name"     { value = aws_lb.api_ext.dns_name }
output "api_nlb_ext_zone_id"      { value = aws_lb.api_ext.zone_id }
output "api_nlb_ext_target_arn"   { value = aws_lb_target_group.api_ext.arn }

output "api_nlb_int_dns_name"     { value = aws_lb.api_int.dns_name }
output "api_nlb_int_zone_id"      { value = aws_lb.api_int.zone_id }
output "api_nlb_int_target_arn"   { value = aws_lb_target_group.api_int.arn }
output "mcs_nlb_int_target_arn"   { value = aws_lb_target_group.mcs_int.arn }

output "apps_nlb_dns_name"        { value = aws_lb.apps.dns_name }
output "apps_nlb_zone_id"         { value = aws_lb.apps.zone_id }
output "apps_nlb_http_target_arn" { value = aws_lb_target_group.apps_http.arn }
output "apps_nlb_https_target_arn"{ value = aws_lb_target_group.apps_https.arn }
