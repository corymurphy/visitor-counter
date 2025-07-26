resource "cloudflare_dns_record" "development" {
  zone_id = var.cloudflare_zone_id
  name    = "visitor-counter-development.${var.apex_domain}"
  content = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "production" {
  zone_id = var.cloudflare_zone_id
  name    = "visitor-counter.${var.apex_domain}"
  content = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 1
  proxied = true
}
