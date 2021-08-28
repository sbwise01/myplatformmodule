variable "platform_name" {}

variable "zones" {
  description = "Availabilty zones to create VPC in.  Should always be 3 AZs."
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "map_roles" {
  default = []
}

variable "workers_additional_policies" {
  default = []
}
