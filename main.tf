#------------------------------------------------------------------------------
# Collect necessary data
#------------------------------------------------------------------------------
data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

data "aws_caller_identity" "current" {}

data "aws_lb" "this" {
  name = var.lb_name
}

data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

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

#------------------------------------------------------------------------------
# Create an ACM Certificate using DNS Validation
# Variables:
#     tld           Top Level Domain
#     app_name      Application Name for the Certificate
#------------------------------------------------------------------------------
data "aws_route53_zone" "external" {
  name = var.tld
}

resource "aws_acm_certificate" "acm_cert" {
  domain_name = "${var.service_name}.${var.tld}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation_record" {
  name = aws_acm_certificate.acm_cert.domain_validation_options.0.resource_record_name
  type = aws_acm_certificate.acm_cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.external.zone_id
  records = [aws_acm_certificate.acm_cert.domain_validation_options.0.resource_record_value]
  ttl = 60
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation_record.fqdn]
}

#------------------------------------------------------------------------------
# Create an HTTPS LB
# Requires aws_acm_certificate - DNS Validation
# Variables:
#     app_name      Application Name for the Certificate
#     app_port      Port the Application LB Listens on
#------------------------------------------------------------------------------
resource "aws_lb_listener" "https_alb_listener" {
  load_balancer_arn = data.aws_lb.this.arn
  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate.acm_cert.arn
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.https_target_group.arn
  }
}

resource "aws_lb_target_group" "https_target_group" {
  name = "${var.service_name}-ecs-tg"
  port = lookup(var.port_mappings[0], "hostPort")
  protocol = "HTTP"
  vpc_id = data.aws_vpc.this.id

  health_check {
    interval = 60
    path = var.health_check_path
    timeout = 5
    healthy_threshold = 2
    port = lookup(var.port_mappings[0], "hostPort")
  }
}

resource "aws_lb_listener_rule" "https_alb_listener_rule" {
  listener_arn = aws_lb_listener.https_alb_listener.arn
  priority = 1
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.https_target_group.arn
  }
  condition {
    field = "host-header"
    values = [
      aws_route53_record.alb_dns.fqdn]
  }
}

#------------------------------------------------------------------------------
# Create DNS Record
# Variables:
#     app_name      Application Name for the Certificate
#------------------------------------------------------------------------------
resource "aws_route53_record" "alb_dns" {
  name    = var.service_name
  type    = "A"
  zone_id = data.aws_route53_zone.external.zone_id
  alias {
    evaluate_target_health = false
    name                   = data.aws_lb.this.name
    zone_id                = data.aws_lb.this.zone_id
  }
}
