#------------------------------------------------------------------------------
# Collect necessary data
#------------------------------------------------------------------------------
data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

//
data "template_file" "task_definition" {
  template = <<EOF
[
  {
    "name": "jenkins-master",
    "image": "jenkins/jenkins",
    "cpu": 128,
    "memory": 1024,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      },
      {
        "containerPort": 50000,
        "hostPort": 50000
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "jenkins_home",
        "containerPath": "/var/jenkins_home"
      }
    ]
  }
]
EOF
//  vars = {
//    service_name = var.service_name
//    image_name = var.image_name
////    port_mappings = jsonencode(var.port_mappings)
////    mount_points = jsonencode(var.mount_points)
////    env_variables = jsonencode(var.env_variables)
//  }
}

//data "template_file" "task_template" {
//  template = file("templates/service.json.tmpl")
//}

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
  task_definition = aws_ecs_task_definition.this.arn
  cluster = data.aws_ecs_cluster.this.id
  desired_count = var.service_desired_count
}