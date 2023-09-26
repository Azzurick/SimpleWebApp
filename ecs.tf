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
  desired_count   = 1
  network_configuration {
    subnets = ["subnet-064fb686de4d173d9"] #hardcoded subnet
    security_groups = [aws_security_group.security_group.id]
    assign_public_ip = true
  }
  force_new_deployment = true

  depends_on = [aws_iam_role.ecs_execution_role]
}

resource "aws_security_group" "security_group" {
  name        = "simple-webapp-sec-group"
  description = "Security group for simple webapp"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
