variable "public_key_path" {
  description = "Path to public key"
  default     = ""
}

variable "ec2_amis" {
  default = {
    us-west-1 = "ami-00831fc7c1e3ddc60"
  }
}