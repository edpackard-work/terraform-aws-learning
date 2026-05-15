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
  count         = 2
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  # Placed in the first Private Subnet
  subnet_id              = aws_subnet.private[count.index].id
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
      res.end('Hello from Instance ${count.index + 1} located in ${data.aws_availability_zones.available.names[count.index]}!\n');
    });
    server.listen(80, () => {
      console.log('Server running on port 80');
    });
    APP
    node /home/ec2-user/server.js &
  EOF

  tags = merge(var.tags, { Name = "2-node-app-${count.index + 1}" })
}