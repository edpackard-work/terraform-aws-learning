variable "tags" {
  description = "Baseline tags for resources"
  type        = map(string)
  default = {
    "Environment" = "ep-learning"
  }
}
