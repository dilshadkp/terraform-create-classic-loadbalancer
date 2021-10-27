######################################
#fetch AZs
######################################


data "aws_availability_zones" "az" {
  state = "available"
}
######################################
#key pair
######################################

resource "aws_key_pair" "mykey" {
  key_name      = "mykey"
  public_key    = "ssh-rsa AAAAB3NzaC1yc------------------------------------------------------------
-------------------------------------------------------------------------------------.compute.internal"
}

######################################
#Launch configuration
######################################

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
######################################
#Autoscaling group
######################################
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

######################################
#Classic elb
######################################
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
######################################
#Security group
######################################
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

