data "template_file" "provision-core" {
  template = "${file("${path.module}/files/provision.sh")}"

  vars {
    version          = "${var.version}"
    mode             = "CORE"
    members          = "core-cluster.neo4j.${lower(var.stage)}.${lower(var.namespace)}"
    initial_password = "${var.initial_password}"
  }
}

data "template_file" "provision-replica" {
  template = "${file("${path.module}/files/provision.sh")}"

  vars {
    version          = "${var.version}"
    mode             = "READ_REPLICA"
    members          = "core-cluster.neo4j.${lower(var.stage)}.${lower(var.namespace)}"
    initial_password = "${var.initial_password}"
  }
}

locals {
  ci_config = <<-CONFIG
      yum_repos:
        neo4j:
          name: Neo4j Stable Repo
          baseurl: https://yum.neo4j.org/stable/
          enabled: true
          gpgcheck: true
          gpgkey: http://debian.neo4j.org/neotechnology.gpg.key

      write_files:
      # Add the resizer script
      - path: /usr/local/bin/resizesrv.sh
        content: |
          #!/bin/bash
          # Do not try to resize twice
          if [ -e /var/lock/resizingsrv ]; then exit; fi

          trap "rm -f /var/lock/resizingsrv; exit" INT TERM EXIT
          touch /var/lock/resizingsrv
          /sbin/resize2fs /dev/xvdg
          rm -f /var/lock/resizingsrv
        permissions: '0755'

      # Add the prepare script
      - path: /usr/local/bin/preparesrv.sh
        content: |
          #!/bin/bash
          # Bail out if already prepared
          FSTYPE="$(lsblk -n -o FSTYPE /dev/xvdg)"
          if [ "$FSTYPE" == "ext4" ]; then exit; fi

          # Wait for the volume to be attached
          while [ ! -b /dev/xvdg ]; do
              sleep 5
          done
          mkfs -t ext4 /dev/xvdg
          tune2fs -i 0 -c 0 /dev/xvdg
          echo /dev/xvdg /srv ext4 defaults,noatime,nodiratime,nofail 0 2 >> /etc/fstab
          mount /srv

          # And now we add to the crontab
          (crontab -l; echo "* * * * * /usr/local/bin/resizesrv.sh >/dev/null 2>&1") | crontab -
        permissions: '0755'
      CONFIG
}

data "template_cloudinit_config" "provision-core" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = "${local.ci_config}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.provision-core.rendered}"
  }
}

data "template_cloudinit_config" "provision-replica" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = "${local.ci_config}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.provision-replica.rendered}"
  }
}
