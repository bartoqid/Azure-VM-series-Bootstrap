variable "prefix" {
  description = "prefix - use your initial"
  default     = "arivaisdwan"
}

variable "location" {
  description = "Australia East"
  default     = "Australia East"
}

variable "admin_username" {
  description = "firewall admin, do not use admin"
  default     = "usertest"
}

variable "admin_password" {
  description = "firewall password minimum of eight characters and include a minimum of one lowercase and one uppercase character, as well as one number or special character. "
  default     = "xxxxxxxxxxx"
}


variable "address_space" {
  type        = string
  description = "The address space that is used by the virtual network."
  default     = "10.2.0.0/16"
}

variable "subnet_prefixes_MGT" {
  description = "The address prefix to use for the subnet."
  type        = string
  default     = "10.2.0.0/24"
}

variable "subnet_prefixes_Untrust" {
  description = "The address prefix to use for the subnet."
  type        = "list"
  default     = [
    {
      ip      = ["10.2.1.0/24"]
      name    = "untrust-1"
    },
    {
      ip      = ["10.2.3.0/24"]
      name    = "untrust-2"
    }
  ]
}

variable "subnet_prefixes_Trust" {
  description = "The address prefix to use for the subnet."
  type        = string
  default     = "10.2.2.0/24"
}

variable "firewall-ip-private" {
  description = "IP address of the trust interface."
  type        = string
  default     = "10.2.2.4"
}

variable "firewall-ip-untrust" {
  description = "IP address of the trust interface."
  type        = string
  default     = "10.2.1.4"
}

variable "bootstrap_storage_account" {
  description = "Existing storage account object for bootstrapping and for holding small-sized boot diagnostics. Usually the object is passed from a bootstrap module's output."
  default     = "storageaccount"
  type        = any
}

variable "bootstrap_storage_account_primary_access_key" {
  default     = "accesskey"
  type        = any
}

variable "file_share_name" {
  default     = "boostrap"
  type        = any
}

variable "admin_endpoint" {
  description = "linux server username"
  default     = "usertest"
}

variable "endpoint_password" {
  description = "linux server password"
  default     = "************"
}

