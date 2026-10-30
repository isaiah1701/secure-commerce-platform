variable "name_prefix" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "enable" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
