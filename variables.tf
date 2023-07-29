variable "server_port" {
  description = "The port the serverwill use for HTTP request"
  type = number
  default = 8080
}

variable "cluster_name" {
  description = "Name for all cluster resources"
  type = string
}

variable "db_remote_state_bucket" {
  description = "Name for the S3 bucket for the database's remote state"
  type  = string
}

variable "db_remote_state_key" {
  description = "Path for the database's remote state"
  type  = string
}

variable "instance_type" {
  description = "EC2 instance type for cluster"
  type = string
}

variable "min_size" {
  description = "Minumun number of EC2 instances in the ASG"
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  
}

variable "user_data" {
  type = string
  description = "Deploy sh script"
}

variable "user_data_variables" {
  type = object({
    aws_ecr_url = string
    aws_repository_name = string
    region = string
  })
  description = "Variables for sh script"
}
