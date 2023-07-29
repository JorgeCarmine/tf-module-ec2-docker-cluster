output "alb_dns" {
  value = aws_lb.web_app_lb.dns_name
  description = "DNS of load balancer"
}

output "asg_name" {
  value = aws_autoscaling_group.web_app_ag.name
  description = "Name of the Auto Scaling Group"
}

output "alb_dns_name" {
  value = aws_lb.web_app_lb.dns_name
  description = "Public DNS of the load balancer"
}

output "container_vars" {
  value = var.user_data_variables
}
