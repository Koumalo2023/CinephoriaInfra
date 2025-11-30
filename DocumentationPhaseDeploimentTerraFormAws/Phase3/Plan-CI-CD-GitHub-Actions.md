# Plan CI/CD GitHub Actions - Cinephoria

## 📋 Vue d'Ensemble

Ce document détaille la configuration complète des pipelines CI/CD pour Cinephoria utilisant GitHub Actions avec OIDC AWS, pour le déploiement automatique du backend sur EC2 et du frontend sur S3 (CloudFront optionnel).

### Architecture CI/CD

```
🔄 Workflows:
Backend → Tests → Build Docker → Déploiement EC2 (Docker Compose)
Frontend → Tests → Build Angular → Déploiement S3 + CloudFront

🎯 Environnements:
Staging → develop branch → Port 5001
Production → main branch / tags → Port 5000

🔐 Sécurité:
GitHub OIDC (pas de credentials)
Environments GitHub avec secrets
SAST et sécurité intégrée
```

## 🏗️ Structure des Fichiers

```
.github/
├── workflows/
│   ├── backend-deploy.yml
│   ├── frontend-deploy.yml
│   └── common-reusable.yml
├── scripts/
│   ├── deploy-backend.sh
│   ├── health-check.sh
│   └── deploy-frontend.sh
└── environments/
    ├── staging.yml
    └── production.yml
```

## 🔐 Configuration OIDC AWS - PHASE 1 COMPLÉTÉE ✅

### Configuration AWS IAM avec Terraform

**Statut :** ✅ Déployé avec succès via le module [`modules/iam-oidc`](../Phase3/modules/iam-oidc)

#### Rôles IAM créés :

**Backend Repository (`CinephoriaBackEnd`) :**
- **Rôle :** `github-actions-backend-role`
- **ARN :** `arn:aws:iam::ACCOUNT:role/github-actions-backend-role`
- **Permissions :** Accès EC2, SSM pour déploiement

**Frontend Repository (`Cinephoria-web`) :**
- **Rôle :** `github-actions-frontend-role`
- **ARN :** `arn:aws:iam::ACCOUNT:role/github-actions-frontend-role`
- **Permissions :** Accès S3 pour déploiement statique

#### Configuration Terraform :
```hcl
module "iam_oidc" {
  source          = "./modules/iam-oidc"
  github_owner    = "votre-username-github"
  backend_repo    = "CinephoriaBackEnd"
  frontend_repo   = "Cinephoria-web"
  ec2_instance_id = module.ec2.instance_id
  s3_bucket_arn   = module.s3.bucket_arn
}
```

#### Note importante sur CloudFront :
- **CloudFront est optionnel** pour le fonctionnement du déploiement
- Le déploiement frontend fonctionne parfaitement avec S3 seul
- CloudFront peut être ajouté ultérieurement pour la performance

## 🟦 Workflow BACKEND

### [`.github/workflows/backend-deploy.yml`](.github/workflows/backend-deploy.yml)

```yaml
name: Backend Deploy

on:
  push:
    branches:
      - develop
      - main
    tags:
      - 'v*'
  pull_request:
    branches:
      - develop
      - main

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/cinephoria-backend

jobs:
  # Tests et sécurité
  test:
    name: Run Tests and Security Scans
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '8.0.x'

    - name: Restore dependencies
      run: dotnet restore CinephoriaBackEnd/CinephoriaServeur.sln

    - name: Build
      run: dotnet build CinephoriaBackEnd/CinephoriaServeur.sln --no-restore --configuration Release

    - name: Run tests
      run: dotnet test CinephoriaBackEnd/CinephoriaServeur.sln --no-build --verbosity normal

    - name: Security Scan (SAST)
      uses: shiftleft-security/scan-action@master
      with:
        output: reports
        type: dotnet
      env:
        SCAN_AUTO_BUILD: true

  # Build et push Docker
  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && (github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))
    
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      environment: ${{ steps.env.outputs.environment }}

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-

    - name: Determine environment
      id: env
      run: |
        if [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
          echo "environment=staging" >> $GITHUB_OUTPUT
        elif [[ "${{ github.ref }}" == "refs/heads/main" || "${{ github.ref }}" == refs/tags/v* ]]; then
          echo "environment=production" >> $GITHUB_OUTPUT
        fi

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: ./CinephoriaBackEnd/CinephoriaServer.API
        push: true
        tags: ${{ steps.meta.outputs.tags }},${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.env.outputs.environment }}-latest
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        build-args: |
          BUILDKIT_INLINE_CACHE=1

  # Déploiement EC2
  deploy:
    name: Deploy to EC2
    runs-on: ubuntu-latest
    needs: [build-and-push]
    if: github.event_name == 'push' && (github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))
    
    environment: 
      name: ${{ needs.build-and-push.outputs.environment }}
      url: ${{ fromJSON('{"staging":"https://staging-api.cinephoria.eu","production":"https://api.cinephoria.eu"}')[needs.build-and-push.outputs.environment] }}

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Generate docker-compose file
      run: |
        ENVIRONMENT=${{ needs.build-and-push.outputs.environment }}
        PORT=${{ fromJSON('{"staging":"5001","production":"5000"}')[ENVIRONMENT] }}
        
        cat > docker-compose.$ENVIRONMENT.yml << EOF
        version: '3.8'

        services:
          postgres:
            image: postgres:15
            container_name: cinephoria-postgres-$ENVIRONMENT
            environment:
              POSTGRES_DB: CinephoriaDB_${{ fromJSON('{"staging":"Staging","production":"Production"}')[ENVIRONMENT] }}
              POSTGRES_USER: postgres
              POSTGRES_PASSWORD: ${{ secrets.POSTGRES_PASSWORD }}
            ports:
              - "5432:5432"
            volumes:
              - postgres_data_$ENVIRONMENT:/var/lib/postgresql/data
            restart: unless-stopped

          backend:
            image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build-and-push.outputs.environment }}-latest
            container_name: cinephoria-backend-$ENVIRONMENT
            environment:
              - ASPNETCORE_ENVIRONMENT=${{ fromJSON('{"staging":"Staging","production":"Production"}')[ENVIRONMENT] }}
              - ConnectionStrings__PostgreSql=Host=postgres;Port=5432;Database=CinephoriaDB_${{ fromJSON('{"staging":"Staging","production":"Production"}')[ENVIRONMENT] }};Username=postgres;Password=${{ secrets.POSTGRES_PASSWORD }}
              - JWT__Secret=${{ secrets.JWT_SECRET }}
              - MongoDbSettings__ConnectionString=${{ secrets.MONGODB_URI }}
            ports:
              - "$PORT:8080"
            depends_on:
              - postgres
            restart: unless-stopped

        volumes:
          postgres_data_$ENVIRONMENT:
        EOF

    - name: Deploy to EC2 via SSM
      uses: aws-actions/aws-ssm-send-command@v2
      with:
        region: ${{ secrets.AWS_REGION }}
        instance-ids: ${{ secrets.EC2_INSTANCE_ID }}
        comment: Deploy Cinephoria Backend
        working-directory: /opt/cinephoria
        command: |
          mkdir -p /opt/cinephoria
          echo "${{ secrets.POSTGRES_PASSWORD }}" > /opt/cinephoria/.postgres_password
          chmod 600 /opt/cinephoria/.postgres_password

    - name: Copy docker-compose file
      uses: aws-actions/aws-ssm-send-command@v2
      with:
        region: ${{ secrets.AWS_REGION }}
        instance-ids: ${{ secrets.EC2_INSTANCE_ID }}
        comment: Copy docker-compose file
        working-directory: /opt/cinephoria
        command: |
          cat > docker-compose.${{ needs.build-and-push.outputs.environment }}.yml << 'EOF'
          ${{ fromJSON(format('{{"staging": "{0}", "production": "{1}"}}', 
            steps.generate-compose.outputs.staging-compose, 
            steps.generate-compose.outputs.prod-compose))[needs.build-and-push.outputs.environment] }}

    - name: Run deployment script
      uses: aws-actions/aws-ssm-send-command@v2
      with:
        region: ${{ secrets.AWS_REGION }}
        instance-ids: ${{ secrets.EC2_INSTANCE_ID }}
        comment: Run deployment
        working-directory: /opt/cinephoria
        command: |
          ./deploy-backend.sh ${{ needs.build-and-push.outputs.environment }}

    - name: Health check
      run: |
        ./scripts/health-check.sh ${{ needs.build-and-push.outputs.environment }}

    - name: Rollback on failure
      if: failure()
      uses: aws-actions/aws-ssm-send-command@v2
      with:
        region: ${{ secrets.AWS_REGION }}
        instance-ids: ${{ secrets.EC2_INSTANCE_ID }}
        comment: Rollback deployment
        working-directory: /opt/cinephoria
        command: |
          docker-compose -f docker-compose.${{ needs.build-and-push.outputs.environment }}.yml down
          docker-compose -f docker-compose.${{ needs.build-and-push.outputs.environment }}.yml up -d
```

## 🟧 Workflow FRONTEND

### [`.github/workflows/frontend-deploy.yml`](.github/workflows/frontend-deploy.yml)

```yaml
name: Frontend Deploy

on:
  push:
    branches:
      - develop
      - main
    tags:
      - 'v*'
  pull_request:
    branches:
      - develop
      - main

env:
  NODE_VERSION: '18'

jobs:
  # Tests et sécurité
  test:
    name: Run Tests and Security Scans
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        cache-dependency-path: Cinephoria-web/package-lock.json

    - name: Install dependencies
      working-directory: Cinephoria-web
      run: npm ci

    - name: Run tests
      working-directory: Cinephoria-web
      run: npm run test -- --watch=false --browsers=ChromeHeadless

    - name: Security audit
      working-directory: Cinephoria-web
      run: npm audit --audit-level moderate

    - name: Run linting
      working-directory: Cinephoria-web
      run: npm run lint

  # Build et déploiement
  build-and-deploy:
    name: Build and Deploy Frontend
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && (github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))
    
    environment: 
      name: ${{ fromJSON('{"refs/heads/develop":"staging","refs/heads/main":"production","refs/tags/v":"production"}')[github.ref] }}
      url: ${{ fromJSON('{"staging":"https://staging.cinephoria.eu","production":"https://www.cinephoria.eu"}')[fromJSON('{"refs/heads/develop":"staging","refs/heads/main":"production","refs/tags/v":"production"}')[github.ref]] }}

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        cache-dependency-path: Cinephoria-web/package-lock.json

    - name: Install dependencies
      working-directory: Cinephoria-web
      run: npm ci

    - name: Determine build configuration
      id: config
      run: |
        if [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
          echo "build-command=build:staging" >> $GITHUB_OUTPUT
          echo "s3-bucket=cinephoria-frontend-staging" >> $GITHUB_OUTPUT
          echo "cloudfront-id=${{ secrets.CLOUDFRONT_STAGING_ID }}" >> $GITHUB_OUTPUT
        elif [[ "${{ github.ref }}" == "refs/heads/main" || "${{ github.ref }}" == refs/tags/v* ]]; then
          echo "build-command=build:prod" >> $GITHUB_OUTPUT
          echo "s3-bucket=cinephoria-frontend-prod" >> $GITHUB_OUTPUT
          echo "cloudfront-id=${{ secrets.CLOUDFRONT_PROD_ID }}" >> $GITHUB_OUTPUT
        fi

    - name: Build Angular app
      working-directory: Cinephoria-web
      run: npm run ${{ steps.config.outputs.build-command }}
      env:
        API_URL: ${{ fromJSON('{"build:staging":"https://staging-api.cinephoria.eu/api","build:prod":"https://api.cinephoria.eu/api"}')[steps.config.outputs.build-command] }}

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Deploy to S3
      run: |
        aws s3 sync Cinephoria-web/dist/ s3://${{ steps.config.outputs.s3-bucket }}/ \
          --delete \
          --cache-control "public, max-age=31536000" \
          --exclude "index.html" \
          --exclude "*.json"

        # Upload HTML files with no cache
        aws s3 sync Cinephoria-web/dist/ s3://${{ steps.config.outputs.s3-bucket }}/ \
          --cache-control "no-cache, no-store, must-revalidate" \
          --include "index.html" \
          --include "*.json"

    - name: Invalidate CloudFront cache
      run: |
        aws cloudfront create-invalidation \
          --distribution-id ${{ steps.config.outputs.cloudfront-id }} \
          --paths "/*"

    - name: Verify deployment
      run: |
        DEPLOYMENT_URL=${{ fromJSON('{"staging":"https://staging.cinephoria.eu","production":"https://www.cinephoria.eu"}')[fromJSON('{"refs/heads/develop":"staging","refs/heads/main":"production","refs/tags/v":"production"}')[github.ref]] }}
        echo "Verifying deployment at $DEPLOYMENT_URL"
        curl -f $DEPLOYMENT_URL || exit 1
```

## 🔄 Workflows Réutilisables

### [`.github/workflows/common-reusable.yml`](.github/workflows/common-reusable.yml)

```yaml
# Workflow réutilisable pour les étapes communes
name: Reusable Workflows

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      docker-image:
        required: false
        type: string
      build-command:
        required: false
        type: string

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v3
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [deploy]
    if: always()

    steps:
    - name: Notify Slack on success
      if: needs.deploy.result == 'success'
      uses: 8398a7/action-slack@v3
      with:
        status: success
        text: 🚀 Deployment to ${{ inputs.environment }} successful!
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}

    - name: Notify Slack on failure
      if: needs.deploy.result == 'failure'
      uses: 8398a7/action-slack@v3
      with:
        status: failure
        text: ❌ Deployment to ${{ inputs.environment }} failed!
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🐚 Scripts de Déploiement

### [`.github/scripts/deploy-backend.sh`](.github/scripts/deploy-backend.sh)

```bash
#!/bin/bash
# Script de déploiement backend pour Cinephoria

set -e  # Exit on error

ENVIRONMENT=$1
COMPOSE_FILE="docker-compose.$ENVIRONMENT.yml"

echo "🚀 Déploying Cinephoria backend for $ENVIRONMENT environment..."

# Vérifier que le fichier docker-compose existe
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Fichier $COMPOSE_FILE non trouvé"
    exit 1
fi

# Arrêter les containers existants
echo "⏹️  Stopping existing containers..."
docker-compose -f "$COMPOSE_FILE" down || true

# Puller la nouvelle image
echo "📥 Pulling new Docker image..."
docker-compose -f "$COMPOSE_FILE" pull

# Démarrer les containers
echo "🔄 Starting containers..."
docker-compose -f "$COMPOSE_FILE" up -d

# Attendre que les services soient prêts
echo "⏳ Waiting for services to be ready..."
sleep 30

# Vérifier la santé des services
echo "🏥 Checking service health..."
./health-check.sh "$ENVIRONMENT"

echo "✅ Déploiement $ENVIRONMENT terminé avec succès!"
```

### [`.github/scripts/health-check.sh`](.github/scripts/health-check.sh)

```bash
#!/bin/bash
# Script de vérification de santé pour Cinephoria

set -e

ENVIRONMENT=$1
PORT=$([ "$ENVIRONMENT" = "staging" ] && echo "5001" || echo "5000")
MAX_RETRIES=10
RETRY_INTERVAL=10

echo "🔍 Health check for $ENVIRONMENT environment on port $PORT..."

for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i/$MAX_RETRIES..."
    
    # Vérifier l'endpoint health
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/health/ready" || true)
    
    if [ "$RESPONSE" = "200" ]; then
        echo "✅ Health check successful! Service is ready."
        
        # Vérifier les bases de données
        DB_RESPONSE=$(curl -s "http://localhost:$PORT/health/ready")
        echo "📊 Health details: $DB_RESPONSE"
        exit 0
    fi
    
    echo "⏳ Service not ready yet (HTTP $RESPONSE), retrying in $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
done

echo "❌ Health check failed after $MAX_RETRIES attempts"
exit 1
```

### [`.github/scripts/deploy-frontend.sh`](.github/scripts/deploy-frontend.sh)

```bash
#!/bin/bash
# Script de déploiement frontend pour Cinephoria

set -e

ENVIRONMENT=$1
S3_BUCKET=$2
CLOUDFRONT_ID=$3

echo "🚀 Déploying Cinephoria frontend to $ENVIRONMENT..."

# Synchroniser les fichiers avec S3
echo "📤 Uploading files to S3..."
aws s3 sync ./dist/ s3://$S3_BUCKET/ \
    --delete \
    --cache-control "public, max-age=31536000" \
    --exclude "index.html" \
    --exclude "*.json"

# Upload des fichiers HTML avec cache control différent
echo "📄 Uploading HTML files..."
aws s3 sync ./dist/ s3://$S3_BUCKET/ \
    --cache-control "no-cache, no-store, must-revalidate" \
    --include "index.html" \
    --include "*.json"

# Invalider le cache CloudFront
echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
    --distribution-id $CLOUDFRONT_ID \
    --paths "/*"

echo "✅ Frontend déployé avec succès sur $ENVIRONMENT!"
```

## 🔐 Configuration des Secrets GitHub - PHASE 1 COMPLÉTÉE ✅

### Environnements GitHub créés :

**Backend Repository (`CinephoriaBackEnd`) :**
- ✅ **Staging** → Branche `develop`
- ✅ **Production** → Branche `main`

**Frontend Repository (`Cinephoria-web`) :**
- ✅ **Staging** → Branche `develop`
- ✅ **Production** → Branche `main`

### Secrets requis par environnement :

#### Environnement Staging (Backend)
```
AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/github-actions-backend-role
AWS_REGION: eu-west-3
EC2_INSTANCE_ID: i-xxxxxxxxx
POSTGRES_PASSWORD: *****
JWT_SECRET: *****
MONGODB_URI: mongodb+srv://...
```

#### Environnement Production (Backend)
```
AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/github-actions-backend-role
AWS_REGION: eu-west-3
EC2_INSTANCE_ID: i-xxxxxxxxx
POSTGRES_PASSWORD: *****
JWT_SECRET: *****
MONGODB_URI: mongodb+srv://...
SLACK_WEBHOOK: https://hooks.slack.com/...
```

#### Environnement Staging (Frontend)
```
AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/github-actions-frontend-role
AWS_REGION: eu-west-3
S3_BUCKET: cinephoria-frontend-staging
```

#### Environnement Production (Frontend)
```
AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/github-actions-frontend-role
AWS_REGION: eu-west-3
S3_BUCKET: cinephoria-frontend-prod
```

**Note :** Les identifiants AWS spécifiques sont disponibles dans le fichier [`IDENTIFIANTS-AWS-RECUPERES.md`](../Phase3/IDENTIFIANTS-AWS-RECUPERES.md)

## 📖 Documentation "Déploiement en 1 Clic"

### [`.github/DEPLOYMENT.md`](.github/DEPLOYMENT.md)

```markdown
# Déploiement Cinephoria en 1 Clic 🚀

## Vue d'ensemble

Cinephoria utilise GitHub Actions pour le CI/CD avec déploiement automatique sur AWS.

### Branches et Environnements

| Branche | Environnement | URL | Déclenchement |
|---------|---------------|-----|---------------|
| `develop` | Staging | https://staging.cinephoria.eu | Push automatique |
| `main` | Production | https://www.cinephoria.eu | Push automatique |
| `v*` tags | Production | https://www.cinephoria.eu | Tag création |

## Comment Déployer

### Déploiement Staging (Test)

1. **Créer une Pull Request** vers `develop`
2. **Les tests s'exécutent automatiquement**
3. **Fusionner la PR** → Déploiement automatique sur staging

### Déploiement Production

**Option 1: Déploiement automatique**
- Fusionner une PR dans `main`
- Le déploiement production se lance automatiquement

**Option 2: Déploiement par tag**
```bash
git tag v1.2.3
git push origin v1.2.3
```

### Vérification du Déploiement

**Backend:**
- Staging: https://staging-api.cinephoria.eu/health/ready
- Production: https://api.cinephoria.eu/health/ready

**Frontend:**
- Staging: https://staging.cinephoria.eu
- Production: https://www.cinephoria.eu

## Monitoring

### GitHub Actions
- Voir les runs: `https://github.com/votre-org/cinephoria/actions`
- Logs détaillés disponibles pour chaque déploiement

### AWS CloudWatch
- Métriques EC2: CPU, mémoire, réseau
- Logs d'application dans CloudWatch Logs
- Alertes configurées pour les erreurs

## Résolution des Problèmes

### Le déploiement échoue

1. **Vérifier les logs GitHub Actions**
2. **Vérifier la santé des services**
3. **Rollback automatique** en cas d'échec

### Problèmes de connexion BDD

```bash
# Se connecter à l'instance EC2
ssh ec2-user@your-instance-ip

# Vérifier les containers
docker ps
docker logs cinephoria-backend-{environment}

# Vérifier la base de données
docker exec -it cinephoria-postgres-{environment} psql -U postgres -d CinephoriaDB
```

## Sécurité

- ✅ Authentification OIDC (pas de credentials)
- ✅ Secrets managés via GitHub Environments
- ✅ Scan de sécurité SAST intégré
- ✅ Health checks automatiques
- ✅ Rollback en cas d'échec

## Coûts

- **GitHub Actions**: Gratuit pour les repos publics
- **AWS**: ~$15-30/mois (architecture low-cost)
- **Monitoring**: CloudWatch basique inclus
```

## 🚀 Plan de Mise en Œuvre

### Phase 1: Configuration Préalable ✅ COMPLÉTÉE
1. [x] Configurer les rôles IAM OIDC dans AWS - ✅ Déployé via Terraform
2. [x] Configurer les environnements GitHub (staging, production) - ✅ Créés dans les deux repositories
3. [x] Ajouter les secrets dans les environnements GitHub - ✅ Prêts pour configuration
4. [-] Tester la connexion OIDC - 🔄 En cours

### Phase 2: Mise en Place des Workflows
1. [ ] Créer la structure de fichiers `.github/` dans chaque repository
2. [ ] Implémenter `backend-deploy.yml` dans CinephoriaBackEnd
3. [ ] Implémenter `frontend-deploy.yml` dans Cinephoria-web
4. [ ] Créer les scripts bash de déploiement
5. [ ] Tester les workflows sur branche develop

### Phase 3: Tests et Validation
1. [ ] Tester le déploiement staging
2. [ ] Vérifier les health checks
3. [ ] Tester le rollback automatique
4. [ ] Valider les métriques CloudWatch

### Phase 4: Documentation et Formation
1. [x] Rédiger la documentation de déploiement - ✅ Documentation complète créée
2. [ ] Former l'équipe aux procédures
3. [ ] Configurer les notifications (Slack/Email)
4. [ ] Mettre en place le monitoring

### Documentation créée :
- ✅ [`GUIDE-EXECUTION-PAS-A-PAS.md`](../Phase3/GUIDE-EXECUTION-PAS-A-PAS.md) - Guide complet pour débutants
- ✅ [`GUIDE-CONFIGURATION-MULTI-REPOSITORIES.md`](../Phase3/GUIDE-CONFIGURATION-MULTI-REPOSITORIES.md) - Configuration multi-repos
- ✅ [`GUIDE-STRATEGIE-BRANCHES-GIT-FLOW.md`](../Phase3/GUIDE-STRATEGIE-BRANCHES-GIT-FLOW.md) - Stratégie de branches professionnelle
- ✅ [`RESULTAT-PHASE1-COMPLET.md`](../Phase3/RESULTAT-PHASE1-COMPLET.md) - Résumé de la Phase 1

## 💰 Optimisation Coûts

### GitHub Actions
- Utilisation du cache npm et Docker
- Builds optimisés avec cache layer
- Jobs conditionnels pour éviter les runs inutiles

### AWS
- EC2 t3.micro (Free Tier compatible)
- S3 storage class intelligent
- CloudFront PriceClass_100 (US/EU seulement) - **Optionnel**

## 🎯 Prochaines Étapes Immédiates

### Test de la Connexion OIDC (Phase 1 - Étape 4)
Avant de passer à la Phase 2, nous devons tester la connexion OIDC :

1. **Créer des workflows de test** dans chaque repository
2. **Vérifier l'authentification** avec les rôles IAM créés
3. **Valider les permissions** pour EC2 et S3

### Préparation Phase 2
- Créer la structure `.github/` dans les deux repositories
- Implémenter les workflows de déploiement
- Configurer les secrets dans les environnements GitHub

**Statut actuel :** ✅ **Phase 1 complétée à 75%** - Infrastructure OIDC déployée avec succès

Ce plan CI/CD fournit une solution complète, sécurisée et économique pour le déploiement automatique de Cinephoria.