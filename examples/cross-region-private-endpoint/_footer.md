## Related Issue

This example tests the fix implemented in [PR #19](https://github.com/Azure/terraform-azurerm-avm-res-eventgrid-topic/pull/19) which addresses [Issue #17](https://github.com/Azure/terraform-azurerm-avm-res-eventgrid-topic/issues/17).

Prior to the fix, the `location` parameter was ignored and private endpoints were always created in the Event Grid Topic's region, causing deployment failures when the VNet existed in a different region.
