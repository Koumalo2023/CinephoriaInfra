# Création du bucket S3 pour le state Terraform

## 📋 Étapes pour créer le bucket S3

### 1. Accéder à la console AWS S3
- Connectez-vous à la [console AWS](https://console.aws.amazon.com/)
- Allez dans le service S3
- Cliquez sur "Créer un bucket"

### 2. Configuration du bucket

**Nom du bucket:**
```
cinephoria-terraform-state
```
*Le nom doit être globalement unique*

**Région:**
```
eu-west-3 (Europe - Paris)
```

**Paramètres de base:**
- ✅ Bloquer tout accès public (recommandé)
- ✅ Activer le versioning (important pour la récupération)

**Chiffrement:**
- Chiffrement SSE-S3 (chiffrement géré par AWS)

### 3. Commandes AWS CLI alternatives

Si vous préférez utiliser l'AWS CLI:

```bash
# Créer le bucket
aws s3api create-bucket \
  --bucket cinephoria-terraform-state \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3

# Activer le versioning
aws s3api put-bucket-versioning \
  --bucket cinephoria-terraform-state \
  --versioning-configuration Status=Enabled

# Bloquer l'accès public
aws s3api put-public-access-block \
  --bucket cinephoria-terraform-state \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### 4. Vérification
- Le bucket doit apparaître dans votre liste S3
- Le versioning doit être activé
- Aucun accès public ne doit être autorisé

### ⚠️ Important
- Gardez le nom du bucket, vous en aurez besoin pour configurer `terraform.tfvars`
- Ne supprimez jamais ce bucket une fois utilisé par Terraform