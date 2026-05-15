# Print URL to terminal
output "alb_dns_name" {
  description = "The public URL of the Load Balancer"
  value       = aws_lb.main.dns_name
}