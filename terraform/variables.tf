variable "project" {
  description = "Short project name used in resource names."
  type        = string
  default     = "hellovisits"

  validation {
    condition     = can(regex("^[a-z0-9]{3,11}$", var.project))
    error_message = "project must be 3-11 lowercase letters or digits (it is part of the storage account name)."
  }
}

variable "environment" {
  description = "Environment name: dev or prod."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "polandcentral"
}

variable "app_service_sku" {
  description = "App Service plan SKU, e.g. B1 or S1."
  type        = string
  default     = "B1"
}

variable "always_on" {
  description = "Keep the app loaded when idle. Costs nothing extra, but prevents cold starts."
  type        = bool
  default     = false
}

variable "storage_replication_type" {
  description = "Storage account replication: LRS, ZRS or GRS."
  type        = string
  default     = "LRS"
}
