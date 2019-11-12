#------------------------------------------------------------------------------
# Collect necessary data
#------------------------------------------------------------------------------
data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

data "aws_caller_identity" "current" {}

data "aws_lb" "this" {
  count = length(var.lb_name) > 0 ? 1 : 0
  name = var.lb_name
}

data "aws_vpc" "this" {
  count = length(var.lb_name) > 0 ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_route53_zone" "external" {
  count = length(var.lb_name) > 0 ? 1 : 0
  name = "${var.tld}."
}

#------------------------------------------------------------------------------
# Launch Docker Service
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family             = var.service_name
  execution_role_arn = aws_iam_role.ecs_exec_role.arn
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
  dynamic "volume" {
    for_each = var.volumes
    content {
      name      = volume.value.name
      host_path = lookup(volume.value, "host_path", null)

      dynamic "docker_volume_configuration" {
        for_each = lookup(volume.value, "docker_volume_configuration", [])
        content {
          autoprovision = lookup(docker_volume_configuration.value, "autoprovision", null)
          driver        = lookup(docker_volume_configuration.value, "driver", null)
          driver_opts   = lookup(docker_volume_configuration.value, "driver_opts", null)
          labels        = lookup(docker_volume_configuration.value, "labels", null)
          scope         = lookup(docker_volume_configuration.value, "scope", null)
        }
      }
    }
  }
  tags = merge(
    {
      "Name" = "${var.service_name}-td"
    },
    var.tags
  )
}

resource "aws_ecs_service" "main" {
  count = length(var.lb_name) > 0 ? 1 : 0
  depends_on      = [aws_lb_target_group.https_target_group]
  name            = var.service_name
  task_definition = aws_ecs_task_definition.this.arn
  cluster         = data.aws_ecs_cluster.this.id
  desired_count   = var.service_desired_count
  iam_role        = aws_iam_role.instance_role.arn
  load_balancer {
    target_group_arn = aws_lb_target_group.https_target_group[0].arn
    container_name   = var.service_name
    container_port   = lookup(var.port_mappings[0], "containerPort")
  }
}

resource "aws_ecs_service" "main-no-lb" {
  count = length(var.lb_name) > 0 ? 0 : 1
  depends_on      = [aws_lb_target_group.https_target_group]
  name            = var.service_name
  task_definition = aws_ecs_task_definition.this.arn
  cluster         = data.aws_ecs_cluster.this.id
  desired_count   = var.service_desired_count
  iam_role        = aws_iam_role.instance_role.arn
}

#------------------------------------------------------------------------------
# Create the executor role
#------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_exec_role" {
  name               = "${var.service_name}-exec"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_exec_assume_role_policy.json
  tags = merge(
    {
      "Name" = "${var.service_name}-exec"
    },
    var.tags
  )
}

resource "aws_iam_role_policy" "ecs_exec_role_policy" {
  name   = "${var.service_name}-exec"
  role   = aws_iam_role.ecs_exec_role.id
  policy = data.aws_iam_policy_document.ecs_exec_policy.json
}

data "aws_iam_policy_document" "ecs_exec_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecs_exec_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

#------------------------------------------------------------------------------
# Create the task profile
#------------------------------------------------------------------------------
resource "aws_iam_role" "instance_role" {
  name               = "${var.service_name}-task"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
  tags = merge(
    {
      "Name" = "${var.ecs_cluster_name}-task"
    },
    var.tags
  )
}

resource "aws_iam_role_policy" "instance_role_policy" {
  name   = "${var.service_name}-task"
  role   = aws_iam_role.instance_role.id
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
    ]
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = var.task_iam_policies
    content {
      effect = lookup(task_iam_policies.value, "effect", null)
      actions = lookup(task_iam_policies.value, "actions", null)
      resources = lookup(task_iam_policies.value, "resources", null)
    }
  }
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  }
}

#------------------------------------------------------------------------------
# Create an ACM Certificate using DNS Validation
# Variables:
#     tld           Top Level Domain
#     app_name      Application Name for the Certificate
#------------------------------------------------------------------------------
resource "aws_acm_certificate" "acm_cert" {
  count = length(var.lb_name) > 0 ? 1 : 0
  domain_name       = "${var.service_name}.${var.tld}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation_record" {
  count = length(var.lb_name) > 0 ? 1 : 0
  name    = aws_acm_certificate.acm_cert[0].domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.acm_cert[0].domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.external[0].zone_id
  records = [aws_acm_certificate.acm_cert[0].domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "default" {
  count = length(var.lb_name) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.acm_cert[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation_record[0].fqdn]
}

#------------------------------------------------------------------------------
# Create an HTTPS LB
# Requires aws_acm_certificate - DNS Validation
# Variables:
#     app_name      Application Name for the Certificate
#     app_port      Port the Application LB Listens on
#------------------------------------------------------------------------------
resource "aws_lb_listener" "https_alb_listener" {
  count = length(var.lb_name) > 0 && var.create_listener ? 1 : 0
  load_balancer_arn = data.aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.acm_cert[0].arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https_target_group[0].arn
  }
}

resource "aws_lb_target_group" "https_target_group" {
  count = length(var.lb_name) > 0 ? 1 : 0
  name     = "${var.service_name}-ecs-tg"
  port     = lookup(var.port_mappings[0], "hostPort")
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.this[0].id

  health_check {
    interval          = 60
    path              = var.health_check_path
    timeout           = 5
    healthy_threshold = 2
    port              = lookup(var.port_mappings[0], "hostPort")
  }
  tags = merge(
    {
      "Name" = "${var.service_name}-ecs-tg"
    },
    var.tags
  )
}

resource "aws_lb_listener_rule" "https_alb_listener_rule" {
  count = length(var.lb_name) > 0 ? 1 : 0
  listener_arn = aws_lb_listener.https_alb_listener[0].arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https_target_group[0].arn
  }
  condition {
    field = "host-header"
    values = [
    aws_route53_record.alb_dns[0].fqdn]
  }
}

#------------------------------------------------------------------------------
# Create DNS Record
# Variables:
#     app_name      Application Name for the Certificate
#------------------------------------------------------------------------------
resource "aws_route53_record" "alb_dns" {
  count = length(var.lb_name) > 0 ? 1 : 0
  name    = var.service_name
  type    = "A"
  zone_id = data.aws_route53_zone.external[0].zone_id
  alias {
    evaluate_target_health = false
    name                   = data.aws_lb.this[0].dns_name
    zone_id                = data.aws_lb.this[0].zone_id
  }
}
