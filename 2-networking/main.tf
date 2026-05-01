# Obtain list of working Availability Zones in region
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "2-vpc"
  })
}

resource "aws_subnet" "public" {
  count  = 2
  vpc_id = aws_vpc.main.id

  # Slices the VPC CIDR into smaller chunks (10.0.0.0/24 and 10.0.1.0/24)
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)

  # Plugs subnet 0 into AZ 1, and subnet 1 into AZ 2
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Automatically hands out public IPs to things built in here
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "2-public-subnet-${count.index + 1}"
  })
}

resource "aws_subnet" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  # Offset index by 2 so the IPs don't overlap with the public subnets (10.0.2.0/24 and 10.0.3.0/24)
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Note: map_public_ip_on_launch is missing here on purpose

  tags = merge(var.tags, {
    Name = "2-private-subnet-${count.index + 1}"
  })
}

# Internet Gateway (VPC "Front Door")
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "2-igw"
  })
}

# Elastic IP (required for NAT Gateway to have a static public face)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "2-nat-eip"
  })
}

# NAT Gateway (Provides outbound-only internet access for private subnets)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  # Plugs NAT into the first public subnet
  subnet_id = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "2-nat-gw"
  })
}

# Public Route Table (Routes all internet-bound traffic out the Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "2-public-rt"
  })
}

# Private Route Table (Routes all internet-bound traffic to the NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "2-private-rt"
  })
}

# Attach Public Route Table to both Public Subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Attach Private Route Table to both Private Subnets
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

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

# Find the latest Amazon Linux 2023 OS image
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Application Server
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  # Placed in the first Private Subnet
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Startup script to install Node.js, create a server, and run it
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nodejs
    cat << 'APP' > /home/ec2-user/server.js
    const http = require('http');
    const server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('Hello from the Private Subnet! The NAT Gateway worked!\n');
    });
    server.listen(80, () => {
      console.log('Server running on port 80');
    });
    APP
    node /home/ec2-user/server.js &
  EOF

  tags = merge(var.tags, { Name = "2-node-app" })
}

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

# Target Group Attachment (Links specific EC2 server to the Target Group)
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
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

# Print URL to terminal
output "alb_dns_name" {
  description = "The public URL of the Load Balancer"
  value       = aws_lb.main.dns_name
}