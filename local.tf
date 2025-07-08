locals {
  aws_ami_id = data.aws_ami.joindevops.id
  vpc_id = data.aws_ssm_parameter.vpc_idf.value

  pri_idf = split(",", data.aws_ssm_parameter.pri_idf.value)

  # catalogue_sg_id = data.aws_ssm_parameter.catalogue_sg_idf.value
  sg_id = data.aws_ssm_parameter.sg_idf.value

  # listener_arn = data.aws_ssm_parameter.backend_alb_sg_idf_arn.value
  listener_arn = var.component == "frontend" ? data.aws_ssm_parameter.frontend_alb_sg_idf_arn.value : data.aws_ssm_parameter.backend_alb_sg_idf_arn.value



  tg_port = var.component == "frontend" ? 80 : 8080
  health_check_path = var.component == "frontend" ? "/" : "/health"

  

  rule_header_name = var.component == "frontend" ? "${var.environment}.${var.zone_name}" : "${var.component}.backend-${var.environment}.${var.zone_name}"

  common_tags = {
    project = "roboshop"
    environment = "dev"
    terraform = true
  }
}