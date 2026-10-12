variable "ignore_body_changes" {
  type = object({
    authorization_locks                               = optional(list(string), [])
    authorization_role_assignments                    = optional(list(string), [])
    eventgrid_topics                                  = optional(list(string), [])
    network_private_endpoints                         = optional(list(string), [])
    network_private_endpoints_private_dns_zone_groups = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot-notation paths to ignore on the module's AzAPI resources. Changes take effect after apply. Ignored configuration is not sent to Azure until the path is removed. Non-empty lists require Terraform 1.11 or later.

- `authorization_locks` - Paths ignored on private endpoint locks.
- `authorization_role_assignments` - Paths ignored on private endpoint role assignments.
- `eventgrid_topics` - Paths ignored on the Event Grid Topic.
- `network_private_endpoints` - Paths ignored on private endpoints.
- `network_private_endpoints_private_dns_zone_groups` - Paths ignored on private DNS zone groups.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    authorization_locks                               = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments                    = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    eventgrid_topics                                  = optional(string, "Microsoft.EventGrid/topics@2025-02-15")
    network_private_endpoints                         = optional(string, "Microsoft.Network/privateEndpoints@2024-05-01")
    network_private_endpoints_private_dns_zone_groups = optional(string, "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by the module.

- `authorization_locks` - Resource type and API version for private endpoint locks.
- `authorization_role_assignments` - Resource type and API version for private endpoint role assignments.
- `eventgrid_topics` - Resource type and API version for the Event Grid Topic.
- `network_private_endpoints` - Resource type and API version for private endpoints.
- `network_private_endpoints_private_dns_zone_groups` - Resource type and API version for private DNS zone groups.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration for the module's AzAPI resources. Defaults to provider behavior.

- `error_message_regex` - Error-message patterns that trigger a retry.
- `interval_seconds` - Initial retry interval in seconds.
- `max_interval_seconds` - Maximum retry interval in seconds.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Operation timeouts for the module's AzAPI resources. Values are Go duration strings, such as `30m` or `1h`. Defaults to provider behavior.

- `create` - Timeout for create operations.
- `read` - Timeout for read operations.
- `update` - Timeout for update operations.
- `delete` - Timeout for delete operations.
DESCRIPTION
}
