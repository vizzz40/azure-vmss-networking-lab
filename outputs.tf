output "application_url" {
  description = "Public URL of the load-balanced FastAPI application"
  value       = "http://${azurerm_public_ip.lb_public_ip.fqdn}"
}

output "load_balancer_public_ip" {
  description = "Public IPv4 address of the Azure Load Balancer"
  value       = azurerm_public_ip.lb_public_ip.ip_address
}

output "load_balancer_fqdn" {
  description = "Public FQDN of the Azure Load Balancer"
  value       = azurerm_public_ip.lb_public_ip.fqdn
}

output "resource_group_name" {
  description = "Name of the resource group containing the lab"
  value       = azurerm_resource_group.rg.name
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azurerm_orchestrated_virtual_machine_scale_set.vmss.name
}
