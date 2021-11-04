# Terraform script to setup a Classic Loadbalancer

In this Terraform script, I am creating a **Classic Load Balancer** which is associated to an Autoscaling Group. This will Loadbalance the HTTP traffic among the EC2 instances in the AutoScaling Group.


## Features
- Fully Automated
- Easy to customise and use as the Terraform modules are created using variables,allowing the module to be customized without altering the module's own source code, and allowing modules to be shared between different configurations.
- This script will create a the infrastructure in default VPC. If you want to create your own VPC, [you may click here](https://github.com/dilshadkp/terraform-create-vpc.git).
- AWS informations are defined using tfvars file and can easily changed (Automated/Manual)
- Project name is appended to the resources that are creating which will make easier to identify the resources.

## Prerequisites
- Create an IAM user on your AWS console that have access to create the required resources.
- Create a dedicated directory where you can create terraform configuration files.
- Install Terraform. [Click here for Terraform installation steps](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started)
- Knowledge to the working principles of AWS services especially AutoScaling, Loadbalancers and EC2.

## Pre-Setup
- Define AWS region in which you are going to work in *terraform.tfvars*
```hcl
region          =   ""
```
- Set a Project name in *terraform.tfvars*
```hcl
project          =   ""
```

## 1.Fetch Available Availability Zones in the working AWS region
>This will fetch all available Availability Zones in working AWS region and store the details in variable *az*

```hcl
data "aws_availability_zones" "az" {
  state = "available"
}
```
## 2.Generate and upload SSH key-pair to AWS
- You can generate SSH key-pair from any Linux systems using *ssh-keygen* command as below:
>![alt text](https://i.ibb.co/bWC7wb7/ssh-keygen.png)

- Upload the generated SSH public key to AWS

```hcl
resource "aws_key_pair" "mykey" {
  key_name      = "mykey"
  public_key    = "ssh-rsa AAAAB3NzaC1yc------------------------------------------------------------
-------------------------------------------------------------------------------------.compute.internal"
}
```
# 3.Create Security Group for instnaces in the AutoScaling Group

```hcl
resource "aws_security_group" "webserver" {
  name          = "webserver-sg"
  description   = "allows 22, 80,443 anywhere"
  vpc_id        = aws_default_vpc.default.id

ingress = [
    {
      description       = "port 22"
      from_port         = "22"
      to_port           = "22"
      protocol          = "tcp"
      cidr_blocks       = ["0.0.0.0/0"]
      ipv6_cidr_blocks  = ["::/0"]
      security_groups   = []
      cidr_blocks       = []
      ipv6_cidr_blocks  = []
      self              = false
      prefix_list_ids   = []
    },
    {
      description       = "port 80"
      from_port         = "80"
      to_port           = "80"
      protocol          = "tcp"
      cidr_blocks       = ["0.0.0.0/0"]
      ipv6_cidr_blocks  = ["::/0"]
      self              = false
      prefix_list_ids   = []
      security_groups   = []
    },
    {
      description       = "port 443"
      from_port         = "443"
      to_port           = "443"
      protocol          = "tcp"
      cidr_blocks       = ["0.0.0.0/0"]
      ipv6_cidr_blocks  = ["::/0"]
      self              = false
      prefix_list_ids   = []
      security_groups   = []
    }
]
egress = [
     {
      description      = ""
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
     }
]
 tags = {
    Name    = "${var.project}-webserver-sg"
    Project = var.project
	}
}
```

# 4.Create Launch configuration
>AutoScaling Group will use this Launch configuration to launch EC2 instances

```hcl
resource "aws_launch_configuration" "lc" {
  name_prefix        = "lc-"
  image_id      = var.ami
  instance_type = var.type
  key_name      = aws_key_pair.mykey.key_name
  security_groups  = [aws_security_group.webserver.id]

  lifecycle {
    create_before_destroy = true
  }

}
```

# 5.Create AutoScaling Group
>This will create an AutoScaling Group which launches ec2 instances as configured in above Launch Configuration.
>You can set your **Desired capacity**, **Minimum capacity** and **Maximum capacity** of AutoScaling Group in *terraform.tfvars* file.

```hcl
resource "aws_autoscaling_group" "asg" {
  name_prefix                      = "asg-"
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = var.desired_size
  launch_configuration      = aws_launch_configuration.lc.name
  load_balancers            = [aws_elb.elb.id]
  availability_zones        = [data.aws_availability_zones.az.names[0], data.aws_availability_zones.az.names[1]]
  tag  {
    key     = "Name"
    value   = "webserver"
    propagate_at_launch = true
}
  lifecycle {
    create_before_destroy = true
  }
}
```

# 6.Create Classic LoadBalancer

```hcl
resource "aws_elb" "elb" {
  name               = "elb"
  availability_zones = [data.aws_availability_zones.az.names[0], data.aws_availability_zones.az.names[1]]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  

  health_check {
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.timeout
    interval            = var.interval
    target              = "HTTP:80/"
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 300

 tags = {
    Name    = "${var.project}-webserver-sg"
    Project = var.project
	}
}

output "DNS-name-of-Loadbalancer" {
    value   =   aws_elb.elb.dns_name
}
```
>Here, *cross_zone_load_balancing* is enabled, which means it will be available across multiple Availability Zones in the VPC.

>Also, *connection_draining* is set to true and value is 300 seconds. This means that if an EC2 backend instance fails health checks, the Elastic Load Balancer will not send any new requests to the unhealthy instance. However, it will still allow existing (in-flight) requests to complete for 300 seconds.

>Lastly, I printed the DNS name of the LoadBalancer to **DNS-name-of-Loadbalancer** so that it will be displayed in the screen after the script execution.
That DNS name will be used for seting up the DNS record.

#### Lets validate the terraform files using
```hcl
terraform validate
```
#### Lets plan the architecture and verify once again.
```hcl
terraform plan
```
#### Lets apply the above architecture to the AWS.
```hcl
terraform apply
```

x--------------------x---------------------x---------------------x---------------------x---------------------x---------------------x---------------------x---------------------x
### ⚙️ Connect with Me 

<p align="center">
<a href="mailto:dilshad.lalu@gmail.com"><img src="https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white"/></a>
<a href="https://www.linkedin.com/in/dilshadkp/"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/></a> 
<a href="https://www.instagram.com/dilshad_a.k.a_lalu/"><img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white"/></a>
<a href="https://wa.me/%2B919567344212?text=This%20message%20from%20GitHub."><img src="https://img.shields.io/badge/WhatsApp-25D366?style=for-the-badge&logo=whatsapp&logoColor=white"/></a><br />

