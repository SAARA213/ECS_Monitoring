provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-app-cluster"
}

resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" 
  memory                   = "512" 

  container_definitions = jsonencode([{
    name      = "medusa"
    image     = "637423411572.dkr.ecr.us-east-1.amazonaws.com/medusa-app:a15706349d167306b05dc5b2c379658fe1826db4"
    essential = true

    portMappings = [{
      containerPort = 9000  # Adjust if your application uses a different port
      hostPort      = 9000
      protocol      = "tcp"
    }]
  }])
}

resource "aws_ecs_service" "medusa_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  }
}

resource "aws_appautoscaling_target" "ecs_scaling_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.medusa_cluster.name}/${aws_ecs_service.medusa_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "High CPU Alarm"
  comparison_operator  = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 75  # Adjust threshold as needed
  alarm_description   = "This alarm will trigger scaling up the ECS service."
  
  dimensions = {
    ClusterName = aws_ecs_cluster.medusa_cluster.name
    ServiceName = aws_ecs_service.medusa_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "Low CPU Alarm"
  comparison_operator  = "LessThanThreshold"
  evaluation_periods   = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 30  # Adjust threshold as needed
  alarm_description   = "This alarm will trigger scaling down the ECS service."
  
  dimensions = {
    ClusterName = aws_ecs_cluster.medusa_cluster.name
    ServiceName = aws_ecs_service.medusa_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_down.arn]
}

resource "aws_appautoscaling_policy" "scale_up" {
  name                   = "scale-up"
  policy_type           = "TargetTrackingScaling"
  resource_id           = aws_appautoscaling_target.ecs_scaling_target.id
  scalable_dimension     = aws_appautoscaling_target.ecs_scaling_target.scalable_dimension
  service_namespace      = aws_appautoscaling_target.ecs_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 60
  }
}

resource "aws_appautoscaling_policy" "scale_down" {
  name                   = "scale-down"
  policy_type           = "TargetTrackingScaling"
  resource_id           = aws_appautoscaling_target.ecs_scaling_target.id
  scalable_dimension     = aws_appautoscaling_target.ecs_scaling_target.scalable_dimension
  service_namespace      = aws_appautoscaling_target.ecs_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 30.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 60
  }
}

output "cluster_id" {
  value = aws_ecs_cluster.medusa_cluster.id
}

output "service_name" {
  value = aws_ecs_service.medusa_service.name
}
