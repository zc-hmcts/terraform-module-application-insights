locals {
  env = var.env == "sandbox" ? "sbox" : var.env
  business_area = strcontains(lower(data.azurerm_subscription.current.display_name), "cnp") || strcontains(lower(data.azurerm_subscription.current.display_name), "cftapps") ? "cft" : "sds"

}

data "azurerm_client_config" "current" {
}

data "azurerm_subscription" "current" {
  subscription_id = data.azurerm_client_config.current.subscription_id
}

data "azurerm_windows_function_app" "alerts" {
  provider            = azurerm.private_endpoint
  name                = "${local.business_area}-alerts-slack-${local.env}"
  resource_group_name = "${local.business_area}-alerts-slack-${local.env}"
}

data "azurerm_function_app_host_keys" "host_keys" {
  provider            = azurerm.private_endpoint
  name                = data.azurerm_windows_function_app.alerts.name
  resource_group_name = "${local.business_area}-alerts-slack-${local.env}"
}

resource "azurerm_monitor_action_group" "action_group" {
  name                = "${title(var.product)}-${title(var.env)}-Warning-Alerts"
  resource_group_name = var.resource_group_name
  short_name = "${substr(var.product, 0, 3)}-${local.env}"

  azure_function_receiver {
    function_app_resource_id = data.azurerm_windows_function_app.alerts.id
    function_name            = "httpTrigger"
    http_trigger_url         = "https://${data.azurerm_windows_function_app.alerts.default_hostname}/api/httpTrigger?code=${data.azurerm_function_app_host_keys.host_keys.default_function_key}"
    name                     = "slack-alerts"
    use_common_alert_schema  = true
  }
  dynamic "email_receiver" {
    for_each = var.email_receiver_config != null ? [var.email_receiver_config] : []
    content {
      name          = email_receiver.value["name"]
      email_address = email_receiver.value["email_address"]
    }
  }

  tags = var.common_tags
}