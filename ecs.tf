provider "aws" {
  region = "eu-west-1" # Change to your desired AWS region
}

terraform {
  backend "s3" {
    bucket         = "tf-devsecops-challenge"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
  }
}


resource "aws_ecs_cluster" "cluster" {
  name = "simple-cluster"
}

resource "aws_ecs_task_definition" "task" {
  family                   = "simple-webapp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "webapp-container"
      image = "797189481526.dkr.ecr.eu-west-1.amazonaws.com/decsecopschallenge:latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        },
      ]
    },
  ])
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
        },
      },
    ],
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

resource "aws_ecs_service" "service" {
  name            = "simple-webapp-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  desired_count   = 2
  network_configuration {
    subnets = ["subnet-064fb686de4d173d9", "subnet-0642513b7880c22c0", "subnet-0c5ee9d65240ad92f"] #hardcoded subnets
    security_groups = [aws_security_group.security_group.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "webapp-container"
    container_port   = 80
  }
  force_new_deployment = true

  depends_on = [aws_iam_role.ecs_execution_role, aws_lb_listener.listener]

  triggers = {
    redeployment = var.timestamp_id
  }
}

variable "timestamp_id" {
    type = string
    default = ""
}

resource "aws_security_group" "security_group" {
  name        = "ecs-webapp-sec-group"
  description = "Security group for simple webapp"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_security_group.id]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


resource "aws_lb" "my_alb" {
  name               = "simple-webapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = ["subnet-064fb686de4d173d9", "subnet-0642513b7880c22c0", "subnet-0c5ee9d65240ad92f"]

  enable_deletion_protection = false
}


resource "aws_lb_target_group" "target_group" {
  name     = "ecs-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-067878c0fccfd59af"
  load_balancing_algorithm_type = "round_robin"
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_security_group" "lb_security_group" {
  name        = "alb-sec-group"
  description = "Security group for simple webapp, allows access from all internet"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "alb_dns" {
  value = aws_lb.my_alb.dns_name
}