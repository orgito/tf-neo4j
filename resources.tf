resource "aws_route53_zone" "neo4j" {
  name          = "neo4j.${lower(var.stage)}.${lower(var.namespace)}"
  force_destroy = true

  vpc {
    vpc_id = "${var.vpc}"
  }
}

resource "aws_instance" "core" {
  count                  = "${var.core_count}"
  ami                    = "${data.aws_ami.selected.id}"
  subnet_id              = "${var.subnet}"
  instance_type          = "${var.core_instance_type}"
  vpc_security_group_ids = ["${aws_security_group.neo4j.id}"]
  key_name               = "${var.ssh_key_pair}"

  root_block_device {
    delete_on_termination = true
  }

  user_data = "${data.template_cloudinit_config.provision-core.rendered}"

  depends_on = ["aws_route53_zone.neo4j"]

  tags = {
    Name        = "${lower("${var.namespace}${var.stage}_neo4j_core${count.index}")}"
    Environment = "${var.stage}"
    Role        = "neo4j_core"
    Provision   = "terraform"
    Inventory   = "ansible"
  }

  lifecycle {
    ignore_changes = ["ami", "user_data"]
  }
}

resource "aws_instance" "replica" {
  count                  = "${var.replica_count}"
  ami                    = "${data.aws_ami.selected.id}"
  subnet_id              = "${var.subnet}"
  instance_type          = "${var.replica_instance_type}"
  vpc_security_group_ids = ["${aws_security_group.neo4j.id}"]
  key_name               = "${var.ssh_key_pair}"

  root_block_device {
    delete_on_termination = true
  }

  user_data = "${data.template_cloudinit_config.provision-replica.rendered}"

  depends_on = ["aws_route53_record.core-cluster"]

  tags = {
    Name        = "${lower("${var.namespace}${var.stage}_neo4j_replica${count.index}")}"
    Environment = "${var.stage}"
    Role        = "neo4j_replica"
    Provision   = "terraform"
    Inventory   = "ansible"
  }

  lifecycle {
    ignore_changes = ["ami", "user_data"]
  }
}


resource "aws_ebs_volume" "core" {
  count             = "${var.core_count}"
  availability_zone = "${local.az}"
  type              = "gp2"
  size              = "${var.storage_size}"

  tags = {
    Name        = "${lower("${var.namespace}${var.stage}_neo4j_core${count.index}")}"
    Environment = "${var.stage}"
    Provision   = "terraform"
  }
}

resource "aws_volume_attachment" "core" {
  count        = "${var.core_count}"
  device_name  = "/dev/xvdg"
  volume_id    = "${element(aws_ebs_volume.core.*.id, count.index)}"
  instance_id  = "${element(aws_instance.core.*.id, count.index)}"
  skip_destroy = true

  lifecycle {
    ignore_changes = ["volume_id", "instance_id"]
  }
}


resource "aws_ebs_volume" "replica" {
  count             = "${var.replica_count}"
  availability_zone = "${local.az}"
  type              = "gp2"
  size              = "${var.storage_size}"

  tags = {
    Name        = "${lower("${var.namespace}${var.stage}_neo4j_replica${count.index}")}"
    Environment = "${var.stage}"
    Provision   = "terraform"
  }
}

resource "aws_volume_attachment" "replica" {
  count        = "${var.replica_count}"
  device_name  = "/dev/xvdg"
  volume_id    = "${element(aws_ebs_volume.replica.*.id, count.index)}"
  instance_id  = "${element(aws_instance.replica.*.id, count.index)}"
  skip_destroy = true

  lifecycle {
    ignore_changes = ["volume_id", "instance_id"]
  }
}

resource "aws_route53_record" "core-cluster" {
  zone_id = "${aws_route53_zone.neo4j.zone_id}"
  name    = "core-cluster.neo4j.${lower(var.stage)}.${lower(var.namespace)}"
  type    = "A"
  ttl     = "5"
  records = ["${aws_instance.core.*.private_ip}"]
}

resource "aws_route53_record" "graph" {
  zone_id = "${aws_route53_zone.neo4j.zone_id}"
  name    = "graph.neo4j.${lower(var.stage)}.${lower(var.namespace)}"
  type    = "A"
  ttl     = "5"
  records = ["${aws_instance.core.*.private_ip}"]
}

resource "aws_route53_record" "core" {
  count   = "${var.core_count}"
  zone_id = "${aws_route53_zone.neo4j.zone_id}"
  name    = "core${count.index}.neo4j.${lower(var.stage)}.${lower(var.namespace)}"
  type    = "A"
  ttl     = "5"
  records = ["${element(aws_instance.core.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "replica" {
  count   = "${var.replica_count}"
  zone_id = "${aws_route53_zone.neo4j.zone_id}"
  name    = "replica${count.index}.neo4j.${lower(var.stage)}.${lower(var.namespace)}"
  type    = "A"
  ttl     = "5"
  records = ["${element(aws_instance.replica.*.private_ip, count.index)}"]
}

resource "aws_security_group" "neo4j" {
  name        = "${lower("${var.namespace}${var.stage}_neo4j")}"
  description = "Allow inbound traffic to neo4j"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 7474
    to_port     = 7474
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 7473
    to_port     = 7473
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Bolt"
    from_port   = 7687
    to_port     = 7687
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backups"
    from_port   = 6362
    to_port     = 6372
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Graphite monitoring"
    from_port   = 2003
    to_port     = 2003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus monitoring"
    from_port   = 2004
    to_port     = 2004
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "JMX monitoring"
    from_port   = 3637
    to_port     = 3637
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${lower("${var.namespace}${var.stage}_neo4j")}"
    Environment = "${var.stage}"
    Provision   = "terraform"
  }
}
