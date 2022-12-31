provider "aws" {
    region = "us-east-2"
}

# resource "aws_instance" "test" {
#     ami     = "ami-0283a57753b18025b"
#     instance_type =  "t2.micro"
#     vpc_security_group_ids = [aws_security_group.instance.id]

#     user_data = <<-EOF
#               #!/bin/bash
#               echo "Hello, World" > index.html
#               nohup busybox httpd -f -p ${var.server_port} &
#               EOF

#     tags = {
#         Name = "terraform-test"
#     }
# }

# ASG
resource "aws_launch_configuration" "test" {
    image_id     = "ami-0283a57753b18025b"
    instance_type =  "t2.micro"
    security_groups  = [aws_security_group.instance.id]

    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_security_group" "instance" {
    name = "terraform-test-instance"

    ingress {
        from_port   = var.server_port
        to_port     = var.server_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type        = number
    default     = 8080
}

resource "aws_autoscaling_group" "test" {
    launch_configuration = aws_launch_configuration.test.name
    vpc_zone_identifier = data.aws_subnet_ids.default.ids

    target_group_arns = [aws_lb_target_group.test.arn]
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-test"
        propagate_at_launch = true
    }
  
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id
  
}

# output "public_ip" {
#     value       = aws_instance.test.public_ip
#     description = "The public IP address of the web server"
  
# 

resource "aws_lb" "test" {
    name = "terraform-asg-test"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.default.ids
    security_groups = [aws_security_group.alb.id ]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.test.arn
    port              = 80
    protocol          = "HTTP"  

    default_action {
        type = "fixed-response"

        fixed_response {
          content_type = "text/plain"
          message_body = "404: page not found:"
          status_code  = 404
        }
    }
}

resource "aws_security_group" "alb" {
    name = "terraform-test-alb"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
  
}

resource "aws_lb_target_group" "test" {
    name            = "terraform-asg-test"
    port            = var.server_port
    protocol        = "HTTP"
    vpc_id          = data.aws_vpc.default.id

    health_check {
      path          = "/"
      protocol      = "HTTP"
      matcher       = "200"
      interval      = 15
      timeout       = 3
      healthy_threshold = 2
      unhealthy_threshold = 2 
    }
}


resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority     = 100

    condition {
      path_pattern {
        values = ["*"]
      }
    }

    action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.test.arn
    }
 
}

output "alb_dns_name" {
    value = aws_lb.test.dns_name
}