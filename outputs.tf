output "core_private_ips" {
  value = "${aws_instance.core.*.private_ip}"
}

output "replica_private_ips" {
  value = "${aws_instance.replica.*.private_ip}"
}

output "neo4j_driver_uri" {
  value = "bolt+routing://graph.neo4j.${lower(var.stage)}.${lower(var.namespace)}:7687"
}
