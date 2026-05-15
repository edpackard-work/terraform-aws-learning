# ALB Security Group (Allows HTTP traffic from anywhere on the internet)
resource "aws_security_group" "alb" {
  name        = "2-alb-sg"
  description = "Allow HTTP inbound from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "2-alb-sg" })
}

# EC2 Security Group (Allows HTTP traffic ONLY from the ALB)
resource "aws_security_group" "ec2" {
  name        = "2-ec2-sg"
  description = "Allow HTTP inbound from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # Instead of a CIDR block, reference the ALB's Security Group ID
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Needed so the server can reach the NAT Gateway to download Node.js
  }

  tags = merge(var.tags, { Name = "2-ec2-sg" })
}