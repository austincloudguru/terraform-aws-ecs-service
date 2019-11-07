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
  description = "Port Mappings to deploy"
  type = list(string)
  default = []

//  portMappings = [
//    {
//      containerPort = 27017
//    },
//  ]
}

variable "mount_points" {
  description = "Mount points for the container"
  type = list(string)
  default = []
}

variable "env_variables" {
  description = "Environmental Variables to pass to the container"
  type = list(string)
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