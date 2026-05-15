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