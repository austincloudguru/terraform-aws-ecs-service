#------------------------------------------------------------------------------
# Collect necessary data
#------------------------------------------------------------------------------
data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}


data "template_file" "task_definition" {
  template = <<EOF
  [
    {
      "name": "$${service_name}",
      "image": "$${image_name}",
      "essential": true
    }
  ]

  EOF
  vars = {
    service_name = var.service_name
    image_name = var.image_name
//    port_mappings = jsonencode(var.port_mappings)
//    mount_points = jsonencode(var.mount_points)
//    env_variables = jsonencode(var.env_variables)
  }
}

data "aws_caller_identity" "current" {}

#------------------------------------------------------------------------------
# Launch Docker Service
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  container_definitions = data.template_file.task_definition.rendered
  family = var.service_name
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
}

resource "aws_ecs_service" "main" {
  name = var.service_name
  task_definition = aws_ecs_task_definition.this
  cluster = data.aws_ecs_cluster.this.id
  desired_count = var.service_desired_count
}