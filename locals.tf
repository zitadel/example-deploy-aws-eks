locals {
  project      = "eks-hello"
  cluster_name = "eks-hello"
  common_tags  = { Project = local.project }

  two_public_subnets = slice(
    [for s in data.aws_subnet.public : s.id if contains(var.control_plane_azs, s.availability_zone)],
    0,
    2
  )
}
