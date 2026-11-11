output "resource_group_name" {
  description = "Resource group holding the environment."
  value       = azurerm_resource_group.main.name
}

output "webapp_name" {
  description = "Web app name, used by the pipeline to deploy the package."
  value       = azurerm_linux_web_app.main.name
}

output "webapp_hostname" {
  description = "Public hostname of the web app."
  value       = azurerm_linux_web_app.main.default_hostname
}
