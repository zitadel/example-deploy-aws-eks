data "aws_route53_zone" "subdomain" {
  zone_id = var.route53_zone_id
}

data "aws_elb_hosted_zone_id" "main" {
  //
}