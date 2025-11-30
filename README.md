# Infrastructure AWS Cinephoria - Terraform

Ce projet Terraform déploie l'infrastructure AWS complète pour Cinephoria avec une architecture low-cost optimisée.

## 🏗️ Architecture

- **Frontend**: S3 + CloudFront (Production & Staging)
- **Backend**: EC2 t3.micro + Docker + Nginx
- **Database**: PostgreSQL via Docker (pas de RDS)
- **DNS**: Route53 avec sous-domaines multiples
- **SSL**: ACM wildcard certificate
- **Monitoring**: CloudWatch basique

## 🚀 Déploiement

### Prérequis

1. AWS CLI configuré avec les permissions appropriées
2. Terraform 1.0+
3. Domain `cinephoria.eu` configuré

### Étapes

1. **Configuration initiale**
   ```bash
   cd CinephoriaInfra
   cp terraform.tfvars.example terraform.tfvars
   # Éditer terraform.tfvars avec vos valeurs
   ```

2. **Initialisation**
   ```bash
   terraform init
   ```

3. **Planification**
   ```bash
   terraform plan
   ```

4. **Déploiement**
   ```bash
   terraform apply
   ```

### Coûts Estimés

- **EC2 t3.micro**: ~$8-10/mois
- **S3**: ~$1-2/mois (selon le trafic)
- **CloudFront**: ~$5-15/mois (selon le trafic)
- **Route53**: ~$0.50/mois
- **Total estimé**: ~$15-30/mois

## 🔧 Maintenance

### Mise à jour du Backend

1. Build des nouvelles images Docker
2. SSH vers l'instance EC2
3. Mettre à jour les containers:
   ```bash
   cd /opt/cinephoria
   docker-compose pull
   docker-compose up -d
   ```

### Déploiement du Frontend

1. Build Angular avec les environnements appropriés
2. Upload vers S3:
   ```bash
   # Production
   aws s3 sync dist/prod/ s3://cinephoria-frontend-prod/ --delete
   
   # Staging
   aws s3 sync dist/staging/ s3://cinephoria-frontend-staging/ --delete
   ```

## 🛠️ Modules

Le projet est organisé en modules réutilisables:

- `acm/`: Certificats SSL
- `cloudfront/`: Distributions CDN
- `ec2/`: Instance backend + configuration
- `route53/`: DNS et records
- `s3/`: Buckets frontend
- `cloudwatch/`: Monitoring et alertes

## 🔐 Sécurité

- Les buckets S3 sont privés (accès uniquement via CloudFront)
- Security group restrictif sur EC2
- Mots de passe via variables sensibles Terraform
- Certificats SSL wildcard via ACM
