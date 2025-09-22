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
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  # Map of user-assigned identity resource ids required by the resource (as a map keyed by resource id)
  user_assigned_id_map = length(var.managed_identities.user_assigned_resource_ids) > 0 ? { for id in var.managed_identities.user_assigned_resource_ids : id => {} } : {}
  # Whether any identity needs to be configured
  identity_required = var.managed_identities.system_assigned || length(local.user_assigned_id_map) > 0
  # Compute the identity type string for ARM: SystemAssigned, UserAssigned, or both
  identity_type_str = var.managed_identities.system_assigned && length(local.user_assigned_id_map) > 0 ? "SystemAssigned, UserAssigned" : (var.managed_identities.system_assigned ? "SystemAssigned" : "UserAssigned")
  # Build the identity payload. Include `userAssignedIdentities` key with null when empty so the final
  # azapi provider will omit it when `ignore_null_property = true`.
  identity_block = local.identity_required ? {
    identity = {
      type                   = local.identity_type_str
      userAssignedIdentities = length(local.user_assigned_id_map) > 0 ? local.user_assigned_id_map : null
    }
  } : {}
  # Topic properties merged from explicit module inputs and passthrough `var.properties`.
  topic_properties = merge(
    {},
    var.public_network_access != null ? { publicNetworkAccess = var.public_network_access } : {},
    length(var.inbound_ip_rules) > 0 ? { inboundIpRules = [for r in var.inbound_ip_rules : { ipMask = r.ip_mask, action = r.action }] } : {},
    { disableLocalAuth = var.disable_local_auth },
    { minimumTlsVersionAllowed = var.minimum_tls_version_allowed },
    { dataResidencyBoundary = coalesce(var.data_residency_boundary, "WithinGeopair") },
    var.input_schema != null ? { inputSchema = var.input_schema } : {},
    var.input_schema_mapping != null ? { inputSchemaMapping = var.input_schema_mapping } : {}
  )
}
