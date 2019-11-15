variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_desired_count" {
  description = "Desired Number of Instances to run"
  type        = number
  default     = 1
}

variable "lb_name" {
  description = "Name of the ALB to use"
  type        = string
  default     = ""
}

variable "vpc_name" {
  description = "Name of the VPC to work in"
  type        = string
  default     = ""
}

variable "tld" {
  description = "Top Level Domain to use"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Health Check Path"
  type        = string
  default     = "/"
}

variable "volumes" {
  description = "Task volume definitions as list of configuration objects"
  type = list(object({
    host_path = string
    name      = string
    docker_volume_configuration = list(object({
      autoprovision = bool
      driver        = string
      driver_opts   = map(string)
      labels        = map(string)
      scope         = string
    }))
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "create_listener" {
  description = "Create the https listener"
  type        = bool
  default     = false
}

variable "task_iam_policies" {
  description = "Additional IAM policies for the task"
  type = list(object({
    effect = string
    actions = list(string)
    resources = list(string)
  }))
  default = []
}

variable "network_mode" {
  description = "The Network Mode to run the container at"
  type = string
  default = "bridge"
}
#------------------------------------------------------------------------------
# Container Definition Variables
#------------------------------------------------------------------------------
variable "service_name" {
  description = "Name of the service being deployed"
  type        = string
}

variable "image_name" {
  description = "Name of the image to be deployed"
  type        = string
}

variable "service_cpu" {
  description = "CPU Units to Allocation"
  type        = number
  default     = 128
}

variable "service_memory" {
  description = "Memory to Allocate"
  type        = number
  default     = 1024
}

variable "essential" {
  description = "Whether the task is essential"
  type        = bool
  default     = true
}

variable "privileged" {
  description = "Whether the task is essential"
  type        = bool
  default     = false
}

variable "command" {
  description = "The command that is passed to the container"
  type        = list(string)
  default     = []
}

variable "port_mappings" {
  type = list(object({
    hostPort      = number
    containerPort = number
    protocol      = string
  }))
  default = [{
    hostPort      = 12345
    containerPort = 12345
    protocol      = "tcp"
  }]
}

variable "mount_points" {
  description = "Mount points for the container"
  type        = list(object({}))
  default     = []
}

variable "env_variables" {
  description = "Environmental Variables to pass to the container"
  type        = list(object({}))
  default     = []
}

variable "linux_parameters" {
  description = "Additional Linux Parameters"
  type = object({})
  default = {}
}
