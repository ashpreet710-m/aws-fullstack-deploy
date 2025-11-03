variable "region" {
  type    = string
  default = "us-east-1"
}
variable "key_name" {
  description = "Existing EC2 Key Pair name for SSH (optional). If empty, no keypair."
  type = string
  default = ""
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "ami" {
  type = string
  description = "AMI id for Amazon Linux 2"
  default = ""
}
