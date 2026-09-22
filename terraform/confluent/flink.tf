resource "confluent_flink_compute_pool" "demo" {
  display_name = "${var.name_prefix}-tableflow-demo"
  cloud        = "AWS"
  region       = var.region
  max_cfu      = var.flink_max_cfu
  environment {
    id = confluent_environment.demo.id
  }
}
