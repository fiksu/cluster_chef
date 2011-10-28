maintainer        "Flip Kromer"
maintainer_email  "info@infochimps.org"
description       "Attaches and mounts ebs volumes for use in the hadoop cluster. Heavily inspired by Robert Berger's http://blog.ibd.com/scalable-deployment/using-the-opscode-aws-cookbook-to-attach-an-ec2-ebs-volume/"
version           "0.1"

depends           "aws"

recipe            "ebs::attach_volumes", "Attach specified EBS volumes"
recipe            "ebs::wait_for_attachment", "Wait until EBS volumes are attached"
recipe            "ebs::mount_volumes", "Mount attached EBS volumes"

# http://blog.ibd.com/scalable-deployment/using-the-opscode-aws-cookbook-to-attach-an-ec2-ebs-volume/
