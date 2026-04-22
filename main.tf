module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

module "frontend" {
  source = "./modules/frontend"

  project_name = var.project_name
  environment  = var.environment
}

module "database" {
  source = "./modules/database"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  mongodb_sg_id      = module.security.mongodb_sg_id
  redis_sg_id        = module.security.redis_sg_id
  instance_type      = var.ec2_instance_type
  key_pair_name      = var.ec2_key_pair_name
  mongo_username     = var.mongo_username
  mongo_password     = var.mongo_password
  mongo_db_name      = var.mongo_db_name
}

module "backend" {
  source = "./modules/backend"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.security.alb_sg_id
  backend_sg_id      = module.security.backend_sg_id
  instance_type      = var.ec2_instance_type
  key_pair_name      = var.ec2_key_pair_name
  mongo_host         = module.database.mongo_private_ip
  mongo_username     = var.mongo_username
  mongo_password     = var.mongo_password
  mongo_db_name      = var.mongo_db_name
  redis_host         = module.database.redis_host
  jwt_secret_key     = var.jwt_secret_key
  cloudfront_domain  = module.frontend.cloudfront_domain_name
}

module "observability" {
  source = "./modules/observability"

  project_name = var.project_name
  environment  = var.environment
  instance_ids = module.backend.instance_ids
  target_group_arn = module.backend.target_group_arn
  alb_arn          = module.backend.alb_arn
}
