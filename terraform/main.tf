locals {
  name_suffix = "${var.project}-${var.environment}"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Web app and storage account names must be globally unique.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

# --- Storage for the visit counter -----------------------------------------

resource "azurerm_storage_account" "main" {
  name                            = "st${var.project}${var.environment}${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_table" "visits" {
  name                 = "visits"
  storage_account_name = azurerm_storage_account.main.name
}

# --- App Service -------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "asp-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.name_suffix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = var.always_on
    ftps_state                        = "Disabled"
    minimum_tls_version               = "1.2"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5
    app_command_line                  = "gunicorn --bind=0.0.0.0 --timeout 120 app:app"

    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    APP_ENVIRONMENT                = var.environment
    STORAGE_TABLE_ENDPOINT         = azurerm_storage_account.main.primary_table_endpoint
    STORAGE_TABLE_NAME             = azurerm_storage_table.visits.name
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true" # pip install during zip deploy
  }
}

# The app reads and writes the table with its managed identity, so no
# storage keys or connection strings are stored in app settings.
resource "azurerm_role_assignment" "webapp_table_access" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
