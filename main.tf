resource "aws_lb_target_group" "main" {
  name     = "${var.project}-${var.environment}-${var.component}"
  port     = local.tg_port
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  deregistration_delay = 120
  health_check {
    healthy_threshold   = 2
    interval            = 5
    matcher             = "200-299"
    path                = local.health_check_path
    port                = local.tg_port
    timeout             = 2
    unhealthy_threshold = 3
  }
}

resource "aws_instance" "main" {
  ami                    = local.aws_ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  subnet_id              = local.pri_idf[0]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
}


resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.component} ${var.environment}",
    ]
  }
}


resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on  = [terraform_data.main]
}

resource "aws_ami_from_instance" "main" {
  name               = "${var.project}-${var.environment}-${var.component}_ami"
  source_instance_id = aws_instance.main.id
  depends_on         = [aws_ec2_instance_state.main]
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-${var.component}_ami"
    }
  )
}


resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"

  }

  depends_on = [aws_ami_from_instance.main]
}


# resource "aws_launch_template" "catalogue" {
#   name                                 = "${var.project}.${var.environment}-catalogue"
#   image_id                             = aws_ami_from_instance.catalogue.id
#   instance_initiated_shutdown_behavior = "terminate"
#   instance_type                        = "t2.micro"
#   vpc_security_group_ids               = [local.catalogue_sg_id]
#   update_default_version               = true
#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "${var.project}.${var.environment}-catalogue"
#     }
#   }
#   tag_specifications {
#     resource_type = "volume"

#     tags = {
#       Name = "${var.project}.${var.environment}-catalogue"
#     }
#   }
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${var.project}.${var.environment}-catalogue"
#     }
#   )

# }



# resource "aws_autoscaling_group" "catalogue" {
#   name                      = "${var.project}.${var.environment}-catalogue"
#   max_size                  = 10
#   min_size                  = 1
#   health_check_grace_period = 90
#   health_check_type         = "ELB"
#   desired_capacity          = 1
#   vpc_zone_identifier       = local.pri_idf
#   target_group_arns         = [aws_lb_target_group.catalogue-target-group.arn]

#   launch_template {
#     id      = aws_launch_template.catalogue.id
#     version = aws_launch_template.catalogue.latest_version
#   }


#   timeouts {
#     delete = "15m"
#   }

#   dynamic "tag" {
#     for_each = merge(
#       local.common_tags,
#       {
#         Name = "${var.project}.${var.environment}-catalogue"
#       }
#     )
#     content {
#       key                 = tag.key
#       value               = tag.value
#       propagate_at_launch = true
#     }
#   }


#   instance_refresh {
#     strategy = "Rolling"
#     preferences {
#       min_healthy_percentage = 50
#     }
#     triggers = ["launch_template"]
#   }
# }

# resource "aws_autoscaling_policy" "catalogue" {
#   name                   = "${var.project}.${var.environment}-catalogue"
#   autoscaling_group_name = aws_autoscaling_group.catalogue.name
#   policy_type = "TargetTrackingScaling"
#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }

#     target_value = 75.0
#   }
# }


# resource "aws_lb_listener_rule" "catalogue" {
#   listener_arn = local.listener_arn
#   priority     = 99

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.catalogue-target-group.arn
#   }

#   condition {
#     host_header {
#       values = ["catalogue.backend-${var.environment}.${var.zone_name}"]
#     }
#   }
# }

###################################

resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"

  image_id = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  update_default_version = true # each time you update, new version will become default
  tag_specifications {
    resource_type = "instance"
    # EC2 tags created by ASG
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
    )
  }

  # volume tags created by ASG
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
    )
  }

  # launch template tags
  tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
  )

}

resource "aws_autoscaling_group" "main" {
  name                 = "${var.project}-${var.environment}-${var.component}"
  desired_capacity   = 1
  max_size           = 10
  min_size           = 1
  target_group_arns = [aws_lb_target_group.main.arn]
  vpc_zone_identifier  = local.pri_idf
  health_check_grace_period = 90
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name ="${var.project}-${var.environment}-${var.component}"
      }
    )
    content{
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
    
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  timeouts{
    delete = "15m"
  }
}

resource "aws_autoscaling_policy" "main" {
  name                   = "${var.project}-${var.environment}-${var.component}"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = local.listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = ["${local.rule_header_name}"]
    }
  }
}