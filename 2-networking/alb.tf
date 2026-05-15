# Application Load Balancer (Sits in public subnets to receive internet traffic)
resource "aws_lb" "main" {
  name               = "2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  # Spans across both public subnets for high availability
  subnets = aws_subnet.public[*].id

  tags = merge(var.tags, { Name = "2-alb" })
}

# Target Group (internal routing destination for the ALB)
resource "aws_lb_target_group" "app" {
  name     = "2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = merge(var.tags, { Name = "2-tg" })
}

# ALB Listener (Tells the ALB to listen on Port 80 and forward traffic to the Target Group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}