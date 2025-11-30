# Plan de Configuration Multi-Environnements - Cinephoria

## 📋 Vue d'ensemble

Ce document détaille la stratégie de configuration pour les trois environnements :
- **Local** : Développement sur localhost
- **Staging** : https://staging.cinephoria.eu (frontend) / https://staging-api.cinephoria.eu (backend)
- **Production** : https://www.cinephoria.eu (frontend) / https://api.cinephoria.eu (backend)

## 🎯 Architecture Technique

### Infrastructure AWS Low-Cost
- **EC2 Instance Unique** : Staging + Production sur la même instance
- **Ports** : 
  - Production API → Port 5000
  - Staging API → Port 5001
- **Nginx** : Reverse proxy avec routing par sous-domaine
- **Bases de données** :
  - PostgreSQL via Docker sur EC2
  - MongoDB Atlas Free Tier

## 🎥 BACKEND ASP.NET 8 - Configuration

### Fichiers de Configuration à Créer

#### 1. [`appsettings.Development.json`](CinephoriaBackEnd/CinephoriaServer.API/appsettings.Development.json)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Information"
    }
  },
  "ConnectionStrings": {
    "PostgreSql": "Host=localhost;Port=5432;Database=CinephoriaDB;Username=postgres;Password=postgres;",
    "PostgreSqlProd": "Host=localhost;Port=5432;Database=CinephoriaDB;Username=postgres;Password=postgres;"
  },
  "JWT": {
    "ValidIssuer": "https://localhost:5048",
    "ValidAudience": "https://localhost:4200",
    "LifeSpanInDays": 3,
    "Secret": "POdkfoitofoip32094u3247GREDSADAFi23o487kdjkjfh"
  },
  "AppBaseUrl": "https://localhost:5048",
  "MongoDbSettings": {
    "ConnectionString": "mongodb://localhost:27017",
    "DatabaseName": "CinephoriaDashboardDB"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://localhost:5048"
      },
      "Https": {
        "Url": "https://localhost:7048"
      }
    }
  },
  "AllowedHosts": "*",
  "FrontendSettings": {
    "AllowedOrigins": [
      "http://localhost:4200",
      "https://localhost:4200"
    ]
  }
}
```

#### 2. [`appsettings.Staging.json`](CinephoriaBackEnd/CinephoriaServer.API/appsettings.Staging.json)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "PostgreSql": "Host=localhost;Port=5432;Database=CinephoriaDB_Staging;Username=postgres;Password=${POSTGRES_PASSWORD};",
    "PostgreSqlProd": "Host=localhost;Port=5432;Database=CinephoriaDB_Staging;Username=postgres;Password=${POSTGRES_PASSWORD};"
  },
  "JWT": {
    "ValidIssuer": "https://staging-api.cinephoria.eu",
    "ValidAudience": "https://staging.cinephoria.eu",
    "LifeSpanInDays": 1,
    "Secret": "${JWT_SECRET_STAGING}"
  },
  "AppBaseUrl": "https://staging-api.cinephoria.eu",
  "MongoDbSettings": {
    "ConnectionString": "${MONGODB_ATLAS_CONNECTION_STRING}",
    "DatabaseName": "CinephoriaDashboardDB_Staging"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5001"
      }
    }
  },
  "AllowedHosts": "staging-api.cinephoria.eu",
  "FrontendSettings": {
    "AllowedOrigins": [
      "https://staging.cinephoria.eu"
    ]
  }
}
```

#### 3. [`appsettings.Production.json`](CinephoriaBackEnd/CinephoriaServer.API/appsettings.Production.json)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Error",
      "Microsoft.EntityFrameworkCore": "Error"
    }
  },
  "ConnectionStrings": {
    "PostgreSql": "Host=localhost;Port=5432;Database=CinephoriaDB_Production;Username=postgres;Password=${POSTGRES_PASSWORD};",
    "PostgreSqlProd": "Host=localhost;Port=5432;Database=CinephoriaDB_Production;Username=postgres;Password=${POSTGRES_PASSWORD};"
  },
  "JWT": {
    "ValidIssuer": "https://api.cinephoria.eu",
    "ValidAudience": "https://www.cinephoria.eu",
    "LifeSpanInDays": 7,
    "Secret": "${JWT_SECRET_PRODUCTION}"
  },
  "AppBaseUrl": "https://api.cinephoria.eu",
  "MongoDbSettings": {
    "ConnectionString": "${MONGODB_ATLAS_CONNECTION_STRING}",
    "DatabaseName": "CinephoriaDashboardDB_Production"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5000"
      }
    }
  },
  "AllowedHosts": "api.cinephoria.eu",
  "FrontendSettings": {
    "AllowedOrigins": [
      "https://www.cinephoria.eu"
    ]
  }
}
```

### Modifications à apporter dans [`Program.cs`](CinephoriaBackEnd/CinephoriaServer.API/Program.cs)

#### 1. Configuration des Health Checks
Ajouter après la configuration des bases de données (ligne 77) :

```csharp
// Configuration des Health Checks
builder.Services.AddHealthChecks()
    .AddNpgSql(
        builder.Configuration.GetConnectionString("PostgreSql") ?? 
        builder.Configuration.GetConnectionString("PostgreSqlProd"),
        name: "postgresql",
        tags: new[] { "database", "ready" }
    )
    .AddMongoDb(
        builder.Configuration.GetSection("MongoDbSettings:ConnectionString").Value ?? "mongodb://localhost:27017",
        name: "mongodb",
        tags: new[] { "database", "ready" }
    )
    .AddCheck<MemoryHealthCheck>("memory", tags: new[] { "live" });

// Service de health check mémoire
public class MemoryHealthCheck : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        var memoryInfo = GC.GetGCMemoryInfo();
        var totalMemory = GC.GetTotalMemory(false) / 1024 / 1024; // MB
        
        if (totalMemory > 500) // 500MB threshold
            return Task.FromResult(HealthCheckResult.Degraded($"Memory usage high: {totalMemory}MB"));
        
        return Task.FromResult(HealthCheckResult.Healthy($"Memory usage: {totalMemory}MB"));
    }
}
```

#### 2. Configuration CORS Dynamique
Remplacer l'appel actuel à `AddCustomSecurity` (ligne 216) par :

```csharp
// Configuration CORS dynamique
builder.Services.AddCors(options =>
{
    options.AddPolicy(SecurityExtensions.DEFAULT_POLICY, policy =>
    {
        var allowedOrigins = builder.Configuration.GetSection("FrontendSettings:AllowedOrigins").Get<string[]>() 
                           ?? new[] { "http://localhost:4200" };
        
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});
```

#### 3. Endpoints Health Checks
Ajouter avant `app.Run()` (ligne 276) :

```csharp
// Health Checks endpoints
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live"),
    ResponseWriter = async (context, report) =>
    {
        var result = JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new
            {
                name = e.Key,
                status = e.Value.Status.ToString(),
                duration = e.Value.Duration.TotalMilliseconds
            })
        });
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(result);
    }
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = async (context, report) =>
    {
        var result = JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new
            {
                name = e.Key,
                status = e.Value.Status.ToString(),
                duration = e.Value.Duration.TotalMilliseconds
            })
        });
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(result);
    }
});
```

### Dockerfile ASP.NET Optimisé

Créer [`Dockerfile`](CinephoriaBackEnd/CinephoriaServer.API/Dockerfile) :

```dockerfile
# Étape de build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copier les fichiers projet et restaurer les dépendances
COPY ["CinephoriaServer.API.csproj", "."]
RUN dotnet restore "CinephoriaServer.API.csproj"

# Copier le reste du code et build
COPY . .
RUN dotnet publish "CinephoriaServer.API.csproj" -c Release -o /app/publish

# Étape runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Créer un utilisateur non-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Installer les outils de santé
RUN apt-get update && apt-get install -y curl

# Copier depuis l'étape de build
COPY --from=build /app/publish .

# Changer les permissions
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/health/live || exit 1

# Variables d'environnement
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV ASPNETCORE_ENVIRONMENT=Production

EXPOSE 8080

ENTRYPOINT ["dotnet", "CinephoriaServer.API.dll"]
```

## 🎨 FRONTEND ANGULAR 19 - Configuration

### Fichiers d'Environnement

#### 1. [`environment.ts`](Cinephoria-web/src/environments/environment.ts) (EXISTANT - À MODIFIER)
```typescript
export const environment = {
  production: false,
  apiUrl: 'https://localhost:5048/api',
  appName: 'Cinephoria Web - Local',
  version: '1.0.0',
  domain: 'localhost',
  // Configuration SEO
  seo: {
    title: 'Cinephoria - Votre cinéma en ligne',
    description: 'Découvrez et réservez vos séances de cinéma en ligne',
    keywords: 'cinéma, films, réservation, séances'
  }
};
```

#### 2. [`environment.staging.ts`](Cinephoria-web/src/environments/environment.staging.ts) (NOUVEAU)
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://staging-api.cinephoria.eu/api',
  appName: 'Cinephoria Web - Staging',
  version: '1.0.0-staging',
  domain: 'staging.cinephoria.eu',
  // Configuration SEO
  seo: {
    title: 'Cinephoria Staging - Votre cinéma en ligne',
    description: 'Environnement de test - Cinephoria - Découvrez et réservez vos séances de cinéma en ligne',
    keywords: 'cinéma, films, réservation, séances, test'
  }
};
```

#### 3. [`environment.prod.ts`](Cinephoria-web/src/environments/environment.prod.ts) (EXISTANT - À MODIFIER)
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://api.cinephoria.eu/api',
  appName: 'Cinephoria Web',
  version: '1.0.0',
  domain: 'www.cinephoria.eu',
  // Configuration SEO
  seo: {
    title: 'Cinephoria - Votre cinéma en ligne',
    description: 'Découvrez et réservez vos séances de cinéma en ligne avec Cinephoria',
    keywords: 'cinéma, films, réservation, séances, billetterie en ligne'
  }
};
```

### Configuration Angular.json

Ajouter la configuration staging dans [`angular.json`](Cinephoria-web/angular.json) :

```json
{
  "projects": {
    "Cinephoria-web": {
      "architect": {
        "build": {
          "configurations": {
            "staging": {
              "fileReplacements": [
                {
                  "replace": "src/environments/environment.ts",
                  "with": "src/environments/environment.staging.ts"
                }
              ],
              "optimization": true,
              "outputHashing": "all",
              "sourceMap": false,
              "extractCss": true,
              "namedChunks": false,
              "aot": true,
              "extractLicenses": true,
              "vendorChunk": false,
              "buildOptimizer": true,
              "budgets": [
                {
                  "type": "initial",
                  "maximumWarning": "2mb",
                  "maximumError": "5mb"
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

### Service SEO Dynamique

Créer [`seo.service.ts`](Cinephoria-web/src/app/core/services/seo.service.ts) :

```typescript
import { Injectable, Inject, PLATFORM_ID } from '@angular/core';
import { Meta, Title } from '@angular/platform-browser';
import { isPlatformBrowser } from '@angular/common';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class SeoService {
  constructor(
    private meta: Meta,
    private title: Title,
    @Inject(PLATFORM_ID) private platformId: any
  ) {}

  setSeoData(customData?: {
    title?: string;
    description?: string;
    keywords?: string;
    image?: string;
    url?: string;
  }) {
    const defaultSeo = environment.seo;
    const seoData = { ...defaultSeo, ...customData };

    // Titre de la page
    this.title.setTitle(seoData.title);

    // Meta tags
    this.meta.updateTag({ name: 'description', content: seoData.description });
    this.meta.updateTag({ name: 'keywords', content: seoData.keywords });
    
    // Open Graph
    this.meta.updateTag({ property: 'og:title', content: seoData.title });
    this.meta.updateTag({ property: 'og:description', content: seoData.description });
    this.meta.updateTag({ property: 'og:type', content: 'website' });
    this.meta.updateTag({ property: 'og:url', content: seoData.url || `https://${environment.domain}` });
    
    if (seoData.image) {
      this.meta.updateTag({ property: 'og:image', content: seoData.image });
    }

    // Twitter Card
    this.meta.updateTag({ name: 'twitter:card', content: 'summary_large_image' });
    this.meta.updateTag({ name: 'twitter:title', content: seoData.title });
    this.meta.updateTag({ name: 'twitter:description', content: seoData.description });
  }
}
```

### Dockerfile Angular Optimisé

Créer [`Dockerfile`](Cinephoria-web/Dockerfile) :

```dockerfile
# Étape de build
FROM node:18-alpine AS build

WORKDIR /app

# Copier package files
COPY package*.json ./
RUN npm ci --only=production

# Copier le code source
COPY . .
RUN npm run build:staging

# Étape de production
FROM nginx:alpine

# Copier la configuration nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Copier les fichiers buildés
COPY --from=build /app/dist/cinephoria-web /usr/share/nginx/html

# Exposition du port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### Configuration Nginx

Créer [`nginx.conf`](Cinephoria-web/nginx.conf) :

```nginx
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Brotli compression (si supporté)
    # brotli on;
    # brotli_types text/plain text/css application/json application/javascript text/xml application/xml;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Cache headers pour les assets statiques
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Configuration SPA
        location / {
            try_files $uri $uri/ /index.html;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
    }
}
```

## 🐳 DOCKER-COMPOSE (LOCAL)

Créer [`docker-compose.yml`](docker-compose.yml) à la racine du projet :

```yaml
version: '3.8'

services:
  # Base de données PostgreSQL
  postgres:
    image: postgres:15
    container_name: cinephoria-postgres
    environment:
      POSTGRES_DB: CinephoriaDB
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - cinephoria-network

  # MongoDB
  mongodb:
    image: mongo:6
    container_name: cinephoria-mongodb
    environment:
      MONGO_INITDB_DATABASE: CinephoriaDashboardDB
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
    networks:
      - cinephoria-network

  # Backend ASP.NET
  backend:
    build:
      context: ./CinephoriaBackEnd/CinephoriaServer.API
      dockerfile: Dockerfile
    container_name: cinephoria-backend
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__PostgreSql=Host=postgres;Port=5432;Database=CinephoriaDB;Username=postgres;Password=postgres;
      - MongoDbSettings__ConnectionString=mongodb://mongodb:27017
    ports:
      - "5048:8080"
    depends_on:
      - postgres
      - mongodb
    networks:
      - cinephoria-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Frontend Angular (optionnel - pour développement)
  frontend:
    build:
      context: ./Cinephoria-web
      dockerfile: Dockerfile
      args:
        - ENVIRONMENT=development
    container_name: cinephoria-frontend
    ports:
      - "4200:80"
    depends_on:
      - backend
    networks:
      - cinephoria-network

volumes:
  postgres_data:
  mongodb_data:

networks:
  cinephoria-network:
    driver: bridge
```

## 🔧 Scripts de Déploiement

### Script de Build Staging

Créer [`scripts/build-staging.sh`](scripts/build-staging.sh) :

```bash
#!/bin/bash

echo "🚀 Building Cinephoria Staging..."

# Backend
echo "📦 Building Backend..."
cd CinephoriaBackEnd/CinephoriaServer.API
docker build -t cinephoria-backend-staging:latest .

# Frontend  
echo "🎨 Building Frontend..."
cd ../../Cinephoria-web
npm run build:staging
docker build -t cinephoria-frontend-staging:latest .

echo "✅ Build Staging completed!"
```

### Script de Déploiement EC2

Créer [`scripts/deploy-ec2.sh`](scripts/deploy-ec2.sh) :

```bash
#!/bin/bash

EC2_HOST="your-ec2-instance"
SSH_KEY="path/to/your/key.pem"

echo "🚀 Deploying to EC2..."

# Copier les images Docker
scp -i $SSH_KEY *.tar ec2-user@$EC2_HOST:/tmp/

# Déployer via SSH
ssh -i $SSH_KEY ec2-user@$EC2_HOST << 'EOF'
    # Charger les images
    docker load -i /tmp/cinephoria-backend-staging.tar
    docker load -i /tmp/cinephoria-frontend-staging.tar
    
    # Arrêter les anciens containers
    docker stop cinephoria-backend-staging cinephoria-frontend-staging || true
    docker rm cinephoria-backend-staging cinephoria-frontend-staging || true
    
    # Démarrer les nouveaux containers
    docker run -d \
        --name cinephoria-backend-staging \
        -p 5001:8080 \
        -e ASPNETCORE_ENVIRONMENT=Staging \
        -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
        -e JWT_SECRET_STAGING=$JWT_SECRET_STAGING \
        cinephoria-backend-staging:latest
    
    docker run -d \
        --name cinephoria-frontend-staging \
        -p 8081:80 \
        cinephoria-frontend-staging:latest
        
    echo "✅ Deployment completed!"
EOF
```

## 🔄 Configuration Nginx sur EC2

Créer [`nginx/cinephoria.conf`](nginx/cinephoria.conf) :

```nginx
server {
    listen 80;
    server_name staging.cinephoria.eu;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name staging-api.cinephoria.eu;
    
    location / {
        proxy_pass http://localhost:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}

server {
    listen 80;
    server_name www.cinephoria.eu;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name api.cinephoria.eu;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
```

## 📊 Variables d'Environnement

Créer [`.env.example`](.env.example) :

```env
# PostgreSQL
POSTGRES_PASSWORD=your_secure_password

# JWT Secrets
JWT_SECRET_STAGING=your_staging_jwt_secret
JWT_SECRET_PRODUCTION=your_production_jwt_secret

# MongoDB Atlas
MONGODB_ATLAS_CONNECTION_STRING=mongodb+srv://username:password@cluster.mongodb.net/

# SMTP
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# TMDb API
TMDB_API_KEY=your_tmdb_api_key
```

## 🚀 Étapes de Mise en Œuvre

### Phase 1 : Préparation Locale
1. [ ] Créer les fichiers `appsettings.*.json` pour le backend
2. [ ] Configurer les health checks dans `Program.cs`
3. [ ] Créer les fichiers d'environnement Angular
4. [ ] Mettre à jour `angular.json` avec la configuration staging
5. [ ] Créer le service SEO
6. [ ] Tester le build local

### Phase 2 : Containerisation
1. [ ] Créer les Dockerfiles optimisés
2. [ ] Configurer docker-compose pour le développement local
3. [ ] Tester les containers localement
4. [ ] Vérifier les health checks

### Phase 3 : Préparation Staging
1. [ ] Configurer l'instance EC2
2. [ ] Installer Docker et Nginx
3. [ ] Configurer les DNS pour les sous-domaines staging
4. [ ] Déployer la version staging
5. [ ] Tester l'intégration complète

### Phase 4 : Production
1. [ ] Configurer les variables d'environnement de production
2. [ ] Déployer la version production
3. [ ] Configurer le monitoring et les logs
4. [ ] Mettre en place les sauvegardes

## 💰 Stratégie Low-Cost

### Optimisations Coût AWS
- **EC2** : Instance t3.micro/t3.small (éligible Free Tier)
- **EBS** : Volume gp2 de 20-30GB
- **Pas de Load Balancer** : Nginx fait le routing
- **Pas de RDS** : PostgreSQL dans Docker
- **MongoDB Atlas** : Free Tier (512MB)
- **DNS** : Route53 pour les sous-domaines

### Monitoring Gratuit
- **Health Checks** : Endpoints intégrés
- **Logs** : Fichiers logs + Serilog
- **Métriques** : Health checks Docker + endpoints custom

Ce plan fournit une base solide pour votre configuration multi-environnements avec une approche low-cost tout en maintenant la qualité et la sécurité.