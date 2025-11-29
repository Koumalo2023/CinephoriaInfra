# Configuration du fichier terraform.tfvars

## 📋 Informations importantes

**Répertoire:** Le fichier `terraform.tfvars` doit être créé dans le dossier [`CinephoriaInfra/`](CinephoriaInfra/)

**Extension:** `.tfvars` est l'extension correcte pour les fichiers de variables Terraform

## 📋 Étapes pour configurer terraform.tfvars

### 1. Le fichier est déjà créé

Le fichier [`terraform.tfvars`](CinephoriaInfra/terraform.tfvars) a été créé dans le bon répertoire avec l'extension correcte.

### 2. Éditer le fichier avec vos valeurs

Ouvrez le fichier `terraform.tfvars` et configurez les valeurs suivantes:

```hcl
# AWS Configuration
region = "eu-west-3"

# Domain Configuration  
domain_name = "cinephoria.eu"

# EC2 Configuration
ec2_instance_type = "t3.micro"
ec2_key_name      = "cinephoria-key-pair"  # Le nom de votre paire de clés AWS

# Database Configuration
postgres_password = "VotreMotDePassePostgreSQLSuperSecurise123!"

# CloudWatch Configuration (optionnel)
cloudwatch_alarm_actions = []  # Ajouter un ARN SNS si vous voulez des alertes

# Tags
tags = {
  Environment = "production"
  Project     = "Cinephoria"
  Owner       = "VotreNom"
}

# Configuration du backend Terraform (DÉCOMMENTER et configurer)
terraform {
  backend "s3" {
    bucket = "cinephoria-terraform-state"  # Le nom du bucket que vous avez créé
    key    = "cinephoria/infrastructure.tfstate"
    region = "eu-west-3"
  }
}
```

### 3. Instructions détaillées pour chaque variable

**`region`** (obligatoire)
- La région AWS où déployer l'infrastructure
- Défaut: `eu-west-3` (Paris)

**`domain_name`** (obligatoire)
- Votre domaine principal
- Défaut: `cinephoria.eu`

**`ec2_instance_type`** (obligatoire)
- Type d'instance EC2
- Défaut: `t3.micro` (gratuit dans Free Tier)

**`ec2_key_name`** (obligatoire)
- **Nom exact** de votre paire de clés SSH créée dans AWS
- Exemple: `cinephoria-key-pair`

**`postgres_password`** (obligatoire)
- Mot de passe pour la base de données PostgreSQL
- **Doit être sécurisé** - au moins 16 caractères, mélange de lettres, chiffres, symboles

**`cloudwatch_alarm_actions`** (optionnel)
- Liste d'ARNs SNS pour recevoir des alertes
- Exemple: `["arn:aws:sns:eu-west-3:123456789012:alerts"]`

**`tags`** (recommandé)
- Tags pour organiser vos ressources AWS

### 4. Validation du fichier

Vérifiez que:
- Tous les champs obligatoires sont remplis
- Le mot de PostgreSQL est sécurisé
- Le nom de la paire de clés correspond exactement à celui dans AWS
- Le nom du bucket S3 pour le state est correct

### ⚠️ Sécurité importante

- Le fichier `terraform.tfvars` contient des informations sensibles
- **NE COMMITTEZ JAMAIS** ce fichier dans Git
- Ajoutez-le à votre `.gitignore`:

```bash
echo "terraform.tfvars" >> .gitignore
echo "*.tfvars" >> .gitignore