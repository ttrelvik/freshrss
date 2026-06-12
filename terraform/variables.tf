variable "stack_name" {
  type        = string
  description = "The name of the Docker Swarm stack (e.g. freshrss)"
  default     = "freshrss"
}

variable "timezone" {
  type        = string
  description = "The timezone for the application and database"
  default     = "America/New_York"
}

variable "postgres_db" {
  type        = string
  description = "PostgreSQL database name"
  default     = "freshrss"
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL database username"
  default     = "freshrss_user"
}

variable "postgres_password" {
  type        = string
  description = "The pre-existing database password for FreshRSS"
  sensitive   = true
}

variable "freshrss_image" {
  type        = string
  description = "The image name and tag for FreshRSS application"
  default     = "freshrss/freshrss:1.29.1"
}

variable "postgres_image" {
  type        = string
  description = "The image name and tag for PostgreSQL"
  default     = "postgres:16"
}
