# =====================================================================
# PROJECT: PARAMETRIC INFRASTRUCTURE (TERRAFORM VARIABLE DEFINTIONS)
# COMPONENT: INPUT CONTROLLERS FOR DYNAMIC CLOUD ENVIRONMENT SCALING
# =====================================================================

variable "aws_region" {
  type        = string
  description = "The target geographical deployment zone"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "The base classless routing block for the network core"
  default     = "10.0.0.0/16"
}

variable "environment_sizes" {
  type = map(string)
  description = "Dynamically scale computing brackets based on the active workspace"
  default = {
    default = "t2.micro"   # Sandbox/Default tier
    staging = "t3.small"   # Testing tier
    prod    = "m5.large"   # High-performance enterprise production tier
  }
}
