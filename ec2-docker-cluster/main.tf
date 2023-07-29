locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tpc_protocol = "TCP"
  all_ips = ["0.0.0.0/0"]
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_iam_role" "ec2_ecr_read_only" {
  name = "${var.cluster_name}-EC2ContainerRegistryReadOnlyRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ec2_ecr_read_only.name
}

resource "aws_iam_instance_profile" "ec2_ecr_profile" {
  name = "${var.cluster_name}-ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr_read_only.name
}



resource "aws_security_group" "web_ec2_sg" {
  name = "${var.cluster_name}-instances-sg"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "TCP"
    cidr_blocks = local.all_ips
  }
  egress {
    from_port = local.any_port
    to_port = local.any_port
    protocol = local.any_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_launch_configuration" "ec2" {
  image_id = "ami-0f34c5ae932e6f0e4"
  instance_type = var.instance_type
  security_groups = [aws_security_group.web_ec2_sg.id]

  user_data = templatefile(var.user_data, var.user_data_variables)

  iam_instance_profile = aws_iam_instance_profile.ec2_ecr_profile.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_app_ag" {
  launch_configuration = aws_launch_configuration.ec2.name
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns = [aws_lb_target_group.web_app_asg.id] # Load banancer target group
  health_check_type = "ELB" # default EC2

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key = "Name"
    value = "${var.cluster_name}-instance"
    propagate_at_launch = true
  }
}

# Load balancer
resource "aws_security_group" "alb_sg" {
  name = "${var.cluster_name}-load-balancer-sg"
  
  ingress {
    from_port = local.http_port
    to_port = local.http_port
    protocol = local.tpc_protocol
    cidr_blocks = local.all_ips
  }

  egress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = local.tpc_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_lb" "web_app_lb" {
  name = "${var.cluster_name}-load-balancer"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_app_lb.arn
  port = local.http_port
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}

resource "aws_lb_target_group" "web_app_asg" {
  name = "web-app-asg"
  port = var.server_port
  protocol = "HTTP"

  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = 200
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_alb_listener_rule" "lb_listener_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web_app_asg.arn
  }
}
