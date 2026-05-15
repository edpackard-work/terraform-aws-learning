# Highly Available AWS Networking and Auto Scaling

## Overview
This directory contains the Terraform configuration for a foundational, multi-tier AWS architecture. It provisions a Virtual Private Cloud (VPC) spanning two Availability Zones, an Application Load Balancer (ALB) to distribute incoming web traffic, and an Auto Scaling Group (ASG) to manage a fleet of web servers.

The primary goal of this setup is to establish a highly available, fault-tolerant infrastructure where servers are physically isolated from the public internet but can still securely serve web requests.

## Architecture Breakdown

### Networking (vpc.tf)
VPC: The foundational network (10.0.0.0/16).

Subnets: Split across two Availability Zones (eu-west-2a and eu-west-2b). Each AZ contains:

1 Public Subnet: For resources that need direct internet access (the Load Balancer and NAT Gateway).

1 Private Subnet: For resources that should not be directly reachable from the internet (the EC2 servers).

Gateways and Routing: An Internet Gateway (IGW) handles public traffic, while a NAT Gateway allows private instances to download updates securely without exposing themselves to inbound internet traffic.

### Compute and Auto Scaling (ec2.tf)
Launch Template: A blueprint for the EC2 servers. It uses the latest Amazon Linux 2023 AMI and includes a startup script (user_data) that automatically installs Node.js and starts a basic web server. The script pulls the specific Instance ID, Availability Zone, and Private IP using the AWS Instance Metadata Service (IMDSv2) to display on the webpage.

Auto Scaling Group (ASG): Monitors the instances and ensures exactly two servers are running at all times (one in each private subnet). If an instance fails or is terminated, the ASG automatically provisions a replacement from the Launch Template.

### Load Balancing (alb.tf)
Application Load Balancer (ALB): Placed in the public subnets, it receives incoming internet traffic on Port 80 and routes it to the healthy instances managed by the Auto Scaling Group.

Target Group: Continuously checks the health of the EC2 instances. If an instance becomes unresponsive, the ALB stops routing traffic to it.

### Security (security.tf)
Security Group Chaining: * The ALB Security Group allows inbound HTTP (Port 80) traffic from anywhere (0.0.0.0/0).

The EC2 Security Group acts as a strict firewall. Instead of allowing IP addresses, it only accepts traffic originating from the ALB Security Group.

## File Structure
To improve readability and maintainability, the infrastructure is separated into modular files rather than a single main.tf:

vpc.tf: Networking boundaries and routing.

security.tf: Security groups and firewall rules.

ec2.tf: Launch template and Auto Scaling Group.

alb.tf: Load balancer and target group logic.

outputs.tf: Prints the final ALB URL to the terminal.

providers.tf: Provider setup and region definition.

## Testing Performed
Load Balancing: Verified that repeated requests to the ALB URL alternate smoothly between the two backend servers.

Failover and Auto-Healing (Chaos Test): Manually terminated one of the running EC2 instances via the AWS Console.

Result: The ALB immediately stopped routing traffic to the dead instance, keeping the website online via the survivor. Within five minutes, the Auto Scaling Group detected the missing capacity and launched a new replacement instance automatically.

Rolling Updates: Updated the user_data script in the Launch Template.

Result: The instance_refresh block in the ASG safely rotated the instances, terminating the old ones and provisioning new ones with the updated script without downtime.

Network Security Isolation: Attempted to bypass the ALB by attaching an Elastic IP directly to an EC2 instance.

Result: The connection timed out, verifying that the EC2 Security Group successfully blocks all traffic that does not pass through the Load Balancer.

## Deployment

From this directory, run:

```bash
terraform init
terraform plan
terraform apply
```

After applying, Terraform will output the `alb_dns_name`.

To test the application and verify the load balancing, it is recommended to use curl in your terminal rather than a web browser. Modern web browsers often hold connections open or cache responses, which can make it incorrectly appear as though only one server is handling your requests.

Run the following command multiple times:

`curl http://<your_alb_dns_name_here>`

You should see the output alternate between your different Instance IDs, confirming that the Load Balancer is successfully distributing traffic across both servers in your Auto Scaling Group.