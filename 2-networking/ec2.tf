# Find the latest Amazon Linux 2023 OS image
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Launch Template (blueprint)
resource "aws_launch_template" "app" {
  name_prefix   = "2-node-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Launch Templates require base64 encoded user data
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nodejs
    
    # Ask AWS for the server's metadata using IMDSv2
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
    PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

    # Notice 'APP' is no longer in quotes, allowing Bash to inject the variables!
    cat << APP > /home/ec2-user/server.js
    const http = require('http');
    const server = http.createServer((req, res) => {
      // Explicitly telling the browser this is plain text with UTF-8 encoding
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(
        '🚀 AWS Auto Scaling Test\n' +
        '----------------------------------------\n' +
        'Instance ID       : $INSTANCE_ID\n' +
        'Availability Zone : $AZ\n' +
        'Private IP        : $PRIVATE_IP\n'
      );
    });
    server.listen(80, () => {
      console.log('Server running on port 80');
    });
    APP
    
    node /home/ec2-user/server.js &
  EOF
  )
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name = "2-asg"
  # Tell ASG it is allowed to deploy into both private subnets
  vpc_zone_identifier = aws_subnet.private[*].id

  # Tell ASG to automatically register new servers with our ALB Target Group
  target_group_arns = [aws_lb_target_group.app.arn]

  # The ASG rules
  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # trigger rolling updates when template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # Keep at least one server alive while updating
    }
  }

  tag {
    key                 = "Name"
    value               = "2-asg-node-app"
    propagate_at_launch = true
  }
}