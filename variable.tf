variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type = string
}

variable "service_name" {
  description = "Name of the service being deployed"
  type = string
}

variable "image_name" {
  description = "Name of the image to be deployed"
  type = string
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
  type = list
  default = []
}

variable "env_variables" {
  description = "Environmental Variables to pass to the container"
  type = list
  default = []
}

variable "task_volumes" {
  description = "List of volume blocks for task definition"
  type        = "list"
  default     = []
}

variable "service_desired_count" {
  description = "Desired Number of Instances to run"
}