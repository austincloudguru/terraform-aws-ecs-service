# terraform-module-ecs-service
Terraform module for creating an ECS service.


## Variables
| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| ecs_cluster_name | Name for the ECS cluster that will be deployed | string | | yes |
| service_name | Name of the ECS services that will be deployed | string | | yes |
| image_name | Docker image to deploy | string | | yes |
| port_mappings | Port mappings for the docker Container | list(object) | hostPort      = 12345 containerPort = 12345 protocol      = "tcp" | yes |
| mount_points | Mount points for the container | list | [] | no |
| env_variables | Environmental variables to pass to the container | list | [] | no |
service_desired_count | Desired number of instances to run | number | 1 | no |
| service_cpu | CPU units to allocate | number | 128 | no |
| service_memory | Memory to allocate | number | 1024 | no |
| lb_name | Name of the ALB to use | string | "" | no |
| vpc_name | VPC that the service is deployed in | string |  "" | no |
| tld | Top Level Domain to Use | string | "" | no |
| health_check_path | Health check path for the ALB | string | "/" | no |
| volumes | Task Volume definitionats as a list of configuration objects | list(object) | [] | no|
| tags | A map of tags to add to all resources | map(string) | {} | no |
|create_listener | Create the alb listener (only needed once per port) | bool | false | no |
| task_iam_policy | Additional task policies to be applied | list(object) | [] | no |

## Outputs

None.

## Authors
Module is maintained by [Mark Honomichl](https://github.com/austincloudguru).

## License
MIT Licensed.  See LICENSE for full details
