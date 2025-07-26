
resource "google_compute_instance" "app" {
  name         = "visitor-counter"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["visitor-counter", "production", "development", "ssh", "http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }



  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    enable-oslogin     = "TRUE"
    enable-oslogin-2fa = "FALSE"
  }

  metadata_startup_script = file("${path.module}/setup-server.sh")

  service_account {
    email  = google_service_account.deployment.email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_project_service.required_apis]
}

output "instance_ip" {
  value = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
}
