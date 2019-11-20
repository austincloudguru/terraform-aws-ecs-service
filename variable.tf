#------------------------------------------------------------------------------
# Variables for ECS Service Module
#------------------------------------------------------------------------------
variable "service_name" {
  description = "Name of the service being deployed"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
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
    hostPort      = 80
    containerPort = 80
    protocol      = "tcp"
  }]
}

variable "mount_points" {
  description = "Mount points for the container"
  type        = list(object({}))
  default     = []
}

variable "environment" {
  description = "Environmental Variables to pass to the container"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = null
}

variable "linux_parameters" {
  description = "Additional Linux Parameters"
  type = object({
    capabilities = object({
      add = list(string)
      drop = list(string)
    })
  })
  default = null
}

variable "network_mode" {
  description = "The Network Mode to run the container at"
  type = string
  default = "bridge"
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

variable "tld" {
  description = "Top Level Domain to use"
  type        = string
  default     = ""
}

variable "external_zone_id" {
  description = "The External Zone ID to use"
  type        = string
  default     = ""
}

variable "log_configuration" {
  description = "Log configuration options to send to a custom log driver for the container."

  type = object({
    logDriver = string
    options   = map(string)
    secretOptions = list(object({
      name      = string
      valueFrom = string
    }))
  })
  default     = null
}
