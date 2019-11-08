#------------------------------------------------------------------------------
# Collect necessary data
#------------------------------------------------------------------------------
data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

data "aws_caller_identity" "current" {}

#------------------------------------------------------------------------------
# Launch Docker Service
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family = var.service_name
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  container_definitions = jsonencode([
    {
      cpu          = var.service_cpu
      essential    = true
      image        = var.image_name
      memory       = var.service_memory
      name         = var.service_name
      portMappings = var.port_mappings
      mountPoints  = var.mount_points
      environment  = var.env_variables
    }
  ])
}

resource "aws_ecs_service" "main" {
  name = var.service_name
  task_definition = aws_ecs_task_definition.this.arn
  cluster = data.aws_ecs_cluster.this.id
  desired_count = var.service_desired_count
  iam_role = aws_iam_role.instance_role.arn
}

#------------------------------------------------------------------------------
# Create an Instance Profile
#------------------------------------------------------------------------------
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.service_name}-instance_profile"
  role = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name = "${var.service_name}-role"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_role_policy" "instance_role_policy" {
  name = "${var.service_name}-policy"
  role = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.role_policy.json
}

data "aws_iam_policy_document" "role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets",
      "iam:PassRole",
    ]
    resources = ["*"]
  }

}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [
        "ecs.amazonaws.com"
      ]
    }
  }
}
