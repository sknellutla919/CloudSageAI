provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "ml_rg" {
  name     = "ml-chatbot-rg"
  location = "West Europe"
}

# Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "ml-chatbot-aks"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  dns_prefix          = "mlchatbot"
  kubernetes_version  = "1.27"

  default_node_pool {
    name       = "agentpool"
    node_count = 2
    vm_size    = "Standard_DS3_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Azure OpenAI GPT-4 Service
resource "azurerm_cognitive_account" "openai" {
  name                = "ml-chatbot-openai"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

# Azure Cognitive Search
resource "azurerm_search_service" "cognitive_search" {
  name                = "ml-chatbot-search"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  sku                 = "standard"
}

# Azure CosmosDB for storing Jira & Confluence Data
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "mlchatbotcosmos"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.ml_rg.location
    failover_priority = 0
  }
}

# Azure Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "ml-chatbot-log-workspace"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Azure Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                = "ml-chatbot-app-insights"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
}

# Enable AKS Monitoring
resource "azurerm_monitor_diagnostic_setting" "aks_monitoring" {
  name                           = "aks-monitoring"
  target_resource_id             = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.log_analytics.id
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Azure API Management for Exposing Chatbot API
resource "azurerm_api_management" "apim" {
  name                = "ml-chatbot-apim"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  publisher_name      = "Chatbot DevOps"
  publisher_email     = "admin@example.com"
  sku_name            = "Developer_1"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_subnet.id
  }

  hostname_configuration {
    proxy {
      host_name = "cloudsage-api.dev.org"
    }
  }
}


# Azure App Service Plan for Function App
resource "azurerm_app_service_plan" "api_plan" {
  name                = "ml-chatbot-api-plan"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = "B1"
  }
}


# Azure Function App for Jira & Confluence API Extraction
resource "azurerm_function_app" "jira_confluence_api" {
  name                       = "ml-chatbot-api"
  location                   = azurerm_resource_group.ml_rg.location
  resource_group_name        = azurerm_resource_group.ml_rg.name
  app_service_plan_id        = azurerm_app_service_plan.api_plan.id
  storage_account_name       = azurerm_storage_account.api_storage.name
  storage_account_access_key = azurerm_storage_account.api_storage.primary_access_key
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.example.instrumentation_key
  }

  identity {
    type = "SystemAssigned"
  }


  site_config {
   linux_fx_version = "python|3.9"
  }
}

# Azure DevOps Pipeline for CI/CD
resource "azurerm_devops_project" "devops" {
  name                = "ml-chatbot-devops"
  organization_name   = "my-devops-org"
  description         = "CI/CD Pipelines for AI Chatbot"
}

# Azure Storage for Function App
resource "azurerm_storage_account" "api_storage" {
  name                     = "mlchatbotstorage"
  resource_group_name      = azurerm_resource_group.ml_rg.name
  location                 = azurerm_resource_group.ml_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Alert for High Chatbot Response Time
resource "azurerm_monitor_metric_alert" "high_response_time" {
  name                = "HighResponseTimeAlert"
  resource_group_name = azurerm_resource_group.ml_rg.name
  scopes             = [azurerm_application_insights.app_insights.id]
  description        = "Triggered when chatbot response time exceeds 5 seconds."
  severity           = 2

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "ServerResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5000
  }
}

# Alert for Function App Failures
resource "azurerm_monitor_metric_alert" "function_failures" {
  name                = "FunctionAppFailureAlert"
  resource_group_name = azurerm_resource_group.ml_rg.name
  scopes             = [azurerm_function_app.jira_confluence_api.id]
  description        = "Triggered when Function App fails."
  severity           = 2

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 1
  }
}
