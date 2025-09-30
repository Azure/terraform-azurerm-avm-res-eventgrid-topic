locals {
  # Whether any identity needs to be configured
  identity_required = var.managed_identities.system_assigned || length(local.user_assigned_id_map) > 0
  # Compute the identity type string for ARM: SystemAssigned, UserAssigned, or both
  identity_type_str = var.managed_identities.system_assigned && length(local.user_assigned_id_map) > 0 ? "SystemAssigned, UserAssigned" : (var.managed_identities.system_assigned ? "SystemAssigned" : "UserAssigned")
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
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  # Final topic properties: merge base properties with any custom properties from var.properties.
  # The var.properties takes precedence, allowing users to override or extend the base properties.
  topic_properties = merge(local.topic_properties_base, var.properties)
  # Topic properties merged from explicit module inputs and passthrough `var.properties`.
  # This contains the base properties derived from module input variables.
  topic_properties_base = merge(
    {},
    var.public_network_access != null ? { publicNetworkAccess = var.public_network_access } : {},
    length(var.inbound_ip_rules) > 0 ? { inboundIpRules = [for r in var.inbound_ip_rules : { ipMask = r.ip_mask, action = r.action }] } : {},
    { disableLocalAuth = var.disable_local_auth },
    { minimumTlsVersionAllowed = var.minimum_tls_version_allowed },
    { dataResidencyBoundary = coalesce(var.data_residency_boundary, "WithinGeopair") },
    var.input_schema != null ? { inputSchema = var.input_schema } : {},
    var.input_schema_mapping != null ? { inputSchemaMapping = var.input_schema_mapping } : {}
  )
  # Map of user-assigned identity resource ids required by the resource (as a map keyed by resource id)
  user_assigned_id_map = length(var.managed_identities.user_assigned_resource_ids) > 0 ? { for id in var.managed_identities.user_assigned_resource_ids : id => {} } : {}
}
