/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  for_each = google_cloud_run_service.default

  name                  = "cloud-run-neg"
  network_endpoint_type = "SERVERLESS"
  region                = each.value.location
  project               = data.google_project.project.project_id
  cloud_run {
    service = each.value.name
  }
}


module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 6.3"
  name    = "tf-cr-lb"
  project = data.google_project.project.project_id

  ssl                             = true
  managed_ssl_certificate_domains = [var.domain]
  https_redirect                  = true
  
  backends = {
    default = {
      description = null
      groups = [for obj in google_compute_region_network_endpoint_group.cloud_run_neg : {
        group = obj.id,
        description = "Network Endpoint Group for GCP Region ${obj.region}"
      }]
        
      enable_cdn              = false
      security_policy         = google_compute_security_policy.api-policy.id
      custom_request_headers  = null
      custom_response_headers = null

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }
      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }
  depends_on = [
    google_project_service.project,
    google_compute_region_network_endpoint_group.cloud_run_neg
  ]
}


resource "google_compute_security_policy" "api-policy" {
  provider = google-beta
  name     = "api-policy"
  project  = data.google_project.project.project_id

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
  depends_on = [
    google_project_service.project
  ]
}

output "external_ip" {
  value = module.lb-http.external_ip
}