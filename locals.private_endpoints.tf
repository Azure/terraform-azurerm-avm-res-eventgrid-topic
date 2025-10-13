locals {
  # Private endpoint application security group associations.
  # We merge the nested maps from private endpoints and application security group associations into a single map.
  private_endpoint_application_security_group_associations = { for assoc in flatten([
    for pe_k, pe_v in var.private_endpoints : [
      for asg_k, asg_v in pe_v.application_security_group_associations : {
        asg_key         = asg_k
        pe_key          = pe_k
        asg_resource_id = asg_v
      }
    ]
  ]) : "${assoc.pe_key}-${assoc.asg_key}" => assoc }
  private_endpoints = {
    for k, v in var.private_endpoints : k => {
      name                                    = v.name
      role_assignments                        = v.role_assignments
      lock                                    = v.lock
      tags                                    = v.tags
      subnet_resource_id                      = v.subnet_resource_id
      private_dns_zone_group_name             = v.private_dns_zone_group_name
      private_dns_zone_resource_ids           = v.private_dns_zone_resource_ids
      application_security_group_associations = v.application_security_group_associations
      private_service_connection_name         = v.private_service_connection_name
      network_interface_name                  = coalesce(v.network_interface_name, "nic-${coalesce(v.name, "pe-${var.name}-${k}")}")
      location                                = v.location
      resource_group_name                     = v.resource_group_name
      ip_configurations                       = v.ip_configurations
      subresource_names                       = ["topic"]
    }
  }
}
