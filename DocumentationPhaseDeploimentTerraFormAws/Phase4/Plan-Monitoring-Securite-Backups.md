# Plan Monitoring, Qualité, Sécurité, Backups & Optimisation - Cinephoria

## 📋 Vue d'Ensemble

Ce document détaille la configuration complète pour l'observabilité, la sécurité, les sauvegardes et l'optimisation des coûts de Cinephoria, avec une approche low-cost compatible AWS Free Tier.

### Architecture de Monitoring

```
🔍 Logging:
Backend ASP.NET → CloudWatch Logs JSON structuré
Frontend Angular → Application Insights
Docker → AWS Logs Driver
CloudFront → Access Logs (optionnel)

📊 Métriques:
CloudWatch Metrics (EC2, RDS, S3, CloudFront)
Custom Metrics API (latence, erreurs)
Dashboard unifié multi-environnements

🚨 Alerting:
CloudWatch Alarms → SNS → Email/Slack
Alertes critiques (5xx, CPU, Disk)
Alertes business (SLO violations)

💾 Sauvegardes:
PostgreSQL → pg_dump → S3 avec lifecycle
MongoDB Atlas → Snapshots automatiques
S3 → Versioning + Lifecycle
```

## 🔎 1. Logging Structuré

### Configuration Backend ASP.NET

#### [`Program.cs`](CinephoriaBackEnd/CinephoriaServer.API/Program.cs) - Middleware Logging

```csharp
// Ajouter après builder.Services configuration
builder.Services.AddLogging(logging =>
{
    logging.ClearProviders();
    logging.AddConsole();
    logging.AddAWSProvider();
    logging.SetMinimumLevel(LogLevel.Information);
});

// Middleware Correlation ID
builder.Services.AddScoped<CorrelationIdMiddleware>();

// Configuration Serilog pour JSON structuré
Log.Logger = new LoggerConfiguration()
    .Enrich.WithProperty("Application", "CinephoriaAPI")
    .Enrich.WithProperty("Environment", builder.Environment.EnvironmentName)
    .Enrich.With<CorrelationIdEnricher>()
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.AmazonCloudWatch(
        logGroup: $"/cinephoria/api-{builder.Environment.EnvironmentName.ToLower()}",
        logStreamPrefix: "api-",
        createLogGroup: true,
        restrictedToMinimumLevel: LogLevel.Information
    )
    .CreateLogger();

builder.Host.UseSerilog();
```

#### [`CorrelationIdMiddleware.cs`](CinephoriaBackEnd/CinephoriaServer.API/Middleware/CorrelationIdMiddleware.cs)

```csharp
public class CorrelationIdMiddleware
{
    private readonly RequestDelegate _next;
    private const string CorrelationIdHeader = "X-Correlation-ID";

    public CorrelationIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task Invoke(HttpContext context)
    {
        var correlationId = context.Request.Headers[CorrelationIdHeader].FirstOrDefault() 
                          ?? Guid.NewGuid().ToString();
        
        context.Items[CorrelationIdHeader] = correlationId;
        context.Response.Headers[CorrelationIdHeader] = correlationId;

        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            await _next(context);
        }
    }
}

public class CorrelationIdEnricher : ILogEventEnricher
{
    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        var correlationId = CallContext.LogicalGetData("CorrelationId") as string;
        if (!string.IsNullOrEmpty(correlationId))
        {
            var correlationIdProperty = propertyFactory.CreateProperty("CorrelationId", correlationId);
            logEvent.AddPropertyIfAbsent(correlationIdProperty);
        }
    }
}
```

#### [`Dockerfile`](CinephoriaBackEnd/CinephoriaServer.API/Dockerfile) - Configuration Logs Docker

```dockerfile
# Ajouter dans la section runtime
# Logging driver pour CloudWatch
CMD ["dotnet", "CinephoriaServer.API.dll", "--urls", "http://0.0.0.0:8080"]

# Health check avec logging
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/health/live || (echo "Health check failed" && exit 1)
```

### Configuration Frontend Angular

#### [`logging.service.ts`](Cinephoria-web/src/app/core/services/logging.service.ts)

```typescript
import { Injectable } from '@angular/core';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class LoggingService {
  private logQueue: any[] = [];
  private readonly maxQueueSize = 50;

  log(level: 'info' | 'warn' | 'error', message: string, context?: any) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      context,
      environment: environment.production ? 'production' : 'staging',
      userAgent: navigator.userAgent,
      url: window.location.href,
      correlationId: this.getCorrelationId()
    };

    // Enqueue log
    this.logQueue.push(logEntry);
    if (this.logQueue.length > this.maxQueueSize) {
      this.logQueue.shift();
    }

    // Send to backend in production
    if (environment.production) {
      this.sendToBackend(logEntry);
    }

    // Console logging in development
    if (!environment.production) {
      console[level](logEntry);
    }
  }

  private getCorrelationId(): string {
    let correlationId = sessionStorage.getItem('correlationId');
    if (!correlationId) {
      correlationId = this.generateId();
      sessionStorage.setItem('correlationId', correlationId);
    }
    return correlationId;
  }

  private generateId(): string {
    return 'cid_' + Math.random().toString(36).substr(2, 9);
  }

  private sendToBackend(logEntry: any) {
    // Send to backend logging endpoint
    fetch(`${environment.apiUrl}/logs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Correlation-ID': logEntry.correlationId
      },
      body: JSON.stringify(logEntry)
    }).catch(error => {
      console.error('Failed to send log:', error);
    });
  }

  // Public methods
  info(message: string, context?: any) {
    this.log('info', message, context);
  }

  warn(message: string, context?: any) {
    this.log('warn', message, context);
  }

  error(message: string, context?: any) {
    this.log('error', message, context);
  }

  getLogs(): any[] {
    return [...this.logQueue];
  }
}
```

#### [`error-handler.service.ts`](Cinephoria-web/src/app/core/services/error-handler.service.ts)

```typescript
import { Injectable, ErrorHandler } from '@angular/core';
import { LoggingService } from './logging.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  constructor(private loggingService: LoggingService) {}

  handleError(error: any): void {
    const errorContext = {
      stack: error.stack,
      message: error.message,
      name: error.name,
      timestamp: new Date().toISOString()
    };

    this.loggingService.error('Unhandled error occurred', errorContext);
    
    // Send to backend for tracking
    this.sendErrorToBackend(error);
  }

  private sendErrorToBackend(error: any) {
    // Implementation for sending errors to backend
  }
}
```

## 📊 2. Métriques & Dashboard CloudWatch

### Métriques Essentielles

#### Métriques API
- `5xxErrorRate` - Taux d'erreurs 5xx (> 1% alert)
- `4xxErrorRate` - Taux d'erreurs 4xx 
- `LatencyP95` - Latence 95ème percentile (> 1s alert)
- `RequestCount` - Nombre total de requêtes
- `SuccessRate` - Taux de succès (SLI)

#### Métriques EC2
- `CPUUtilization` - Utilisation CPU (> 80% alert)
- `MemoryUtilization` - Utilisation mémoire
- `DiskSpaceUtilization` - Espace disque (< 20% alert)
- `NetworkIn/Out` - Traffic réseau

#### Métriques CloudFront
- `TotalErrorRate` - Taux d'erreurs
- `CacheHitRate` - Taux de cache
- `BytesDownloaded` - Données transférées

### Dashboard CloudWatch Terraform

#### [`modules/cloudwatch-dashboard/main.tf`](CinephoriaInfra/modules/cloudwatch-dashboard/main.tf)

```hcl
resource "aws_cloudwatch_dashboard" "cinephoria" {
  dashboard_name = "Cinephoria-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Section: API Metrics
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# 🚀 Cinephoria API Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "app/cinephoria-alb", "TargetGroup", "targetgroup/cinephoria-api", { "id": "errors5xx", "label": "5XX Errors", "color": "#ff0000" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", ".", ".", { "id": "errors4xx", "label": "4XX Errors", "color": "#ff9900" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", ".", ".", { "id": "success", "label": "2XX Success", "color": "#00ff00" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.region
          title   = "API HTTP Status Codes"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/cinephoria-alb", { "stat": "Average", "label": "Avg Latency" }],
            [".", ".", ".", ".", { "stat": "p95", "label": "P95 Latency" }],
            [".", ".", ".", ".", { "stat": "p99", "label": "P99 Latency" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "API Latency (ms)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/cinephoria-alb", { "label": "Request Count" }],
            [".", "HealthyHostCount", ".", ".", { "label": "Healthy Hosts" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "API Throughput & Health"
          period  = 300
        }
      },

      # Section: EC2 Metrics
      {
        type   = "text"
        x      = 0
        y      = 7
        width  = 24
        height = 1
        properties = {
          markdown = "# 🖥️ EC2 Instance Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ec2_instance_id, { "label": "CPU Utilization" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "CPU Usage (%)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 8
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", var.ec2_instance_id, { "label": "Memory Usage" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Memory Usage (%)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["CWAgent", "disk_used_percent", "InstanceId", var.ec2_instance_id, "device", "xvda1", { "label": "Disk Usage" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Disk Usage (%)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 8
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", var.ec2_instance_id, { "label": "Network In" }],
            [".", "NetworkOut", ".", ".", { "label": "Network Out" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Network Traffic (Bytes)"
          period  = 300
        }
      },

      # Section: CloudFront Metrics
      {
        type   = "text"
        x      = 0
        y      = 14
        width  = 24
        height = 1
        properties = {
          markdown = "# 🌍 CloudFront & S3 Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 15
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_prod_id, "Region", "Global", { "label": "Production Requests" }],
            [".", ".", ".", var.cloudfront_staging_id, ".", ".", { "label": "Staging Requests" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "CloudFront Requests"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 15
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "TotalErrorRate", "DistributionId", var.cloudfront_prod_id, "Region", "Global", { "label": "Prod Error Rate" }],
            [".", ".", ".", var.cloudfront_staging_id, ".", ".", { "label": "Staging Error Rate" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "CloudFront Error Rate (%)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 15
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "StorageType", "AllStorageTypes", "BucketName", var.s3_prod_bucket, { "label": "Prod Objects" }],
            [".", ".", ".", ".", ".", var.s3_staging_bucket, { "label": "Staging Objects" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "S3 Object Count"
          period  = 300
        }
      }
    ]
  })
}
```

## 🚨 3. Alerting Low-Cost

### Configuration CloudWatch Alarms

#### [`modules/cloudwatch-alarms/main.tf`](CinephoriaInfra/modules/cloudwatch-alarms/main.tf)

```hcl
# SNS Topic pour les alertes
resource "aws_sns_topic" "alerts" {
  name = "cinephoria-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# Alertes API
resource "aws_cloudwatch_metric_alarm" "api_5xx_high" {
  alarm_name          = "cinephoria-api-5xx-high"
  alarm_description   = "API 5XX error rate exceeds 1%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10" # 1% of typical traffic
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = "app/cinephoria-alb"
    TargetGroup  = "targetgroup/cinephoria-api"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_latency_high" {
  alarm_name          = "cinephoria-api-latency-high"
  alarm_description   = "API P95 latency exceeds 1 second"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "p95"
  threshold           = "1.0"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = "app/cinephoria-alb"
  }
}

# Alertes EC2
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "cinephoria-ec2-cpu-high"
  alarm_description   = "EC2 CPU utilization exceeds 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_disk_low" {
  alarm_name          = "cinephoria-ec2-disk-low"
  alarm_description   = "EC2 disk space below 20% free"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80" # 80% used = 20% free
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
    device     = "xvda1"
  }
}

# Alerte Backup
resource "aws_cloudwatch_metric_alarm" "backup_failed" {
  alarm_name          = "cinephoria-backup-failed"
  alarm_description   = "Database backup failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BackupSuccess"
  namespace           = "Custom/Cinephoria"
  period              = "3600" # 1 hour
  statistic           = "Sum"
  threshold           = "0"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Database = "PostgreSQL"
  }
}
```

## 💾 4. Backups & Recovery

### Scripts de Sauvegarde PostgreSQL

#### [`scripts/backup-postgres.sh`](scripts/backup-postgres.sh)

```bash
#!/bin/bash
# Script de sauvegarde PostgreSQL vers S3

set -e

ENVIRONMENT=${1:-production}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="cinephoria-postgres-${ENVIRONMENT}-${TIMESTAMP}.sql.gz"
S3_BUCKET="cinephoria-backups-$(aws sts get-caller-identity --query Account --output text)"
S3_PATH="postgres/${ENVIRONMENT}/${BACKUP_FILE}"

echo "🚀 Starting PostgreSQL backup for $ENVIRONMENT environment..."

# Variables d'environnement
if [ "$ENVIRONMENT" = "production" ]; then
    DB_HOST="localhost"
    DB_PORT="5432"
    DB_NAME="CinephoriaDB_Production"
elif [ "$ENVIRONMENT" = "staging" ]; then
    DB_HOST="localhost"
    DB_PORT="5432"
    DB_NAME="CinephoriaDB_Staging"
else
    echo "❌ Environment must be 'production' or 'staging'"
    exit 1
fi

# Lire le mot de passe depuis le fichier sécurisé
DB_PASSWORD=$(cat /opt/cinephoria/.postgres_password)

# Créer le dump et compresser
echo "📦 Creating database dump..."
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U postgres \
    -d "$DB_NAME" \
    --verbose \
    --no-password \
    --format=custom | gzip > "/tmp/${BACKUP_FILE}"

# Vérifier la taille du backup
BACKUP_SIZE=$(stat -c%s "/tmp/${BACKUP_FILE}")
echo "📊 Backup size: $((BACKUP_SIZE / 1024 / 1024)) MB"

# Upload vers S3
echo "☁️  Uploading to S3..."
aws s3 cp "/tmp/${BACKUP_FILE}" "s3://${S3_BUCKET}/${S3_PATH}" \
    --storage-class STANDARD_IA

# Vérifier l'upload
if aws s3 ls "s3://${S3_BUCKET}/${S3_PATH}" > /dev/null; then
    echo "✅ Backup uploaded successfully to s3://${S3_BUCKET}/${S3_PATH}"
    
    # Envoyer une métrique CloudWatch de succès
    aws cloudwatch put-metric-data \
        --namespace "Custom/Cinephoria" \
        --metric-name "BackupSuccess" \
        --value 1 \
        --dimensions Database=PostgreSQL,Environment=$ENVIRONMENT
    
    # Nettoyer le fichier local
    rm -f "/tmp/${BACKUP_FILE}"
else
    echo "❌ Backup upload failed"
    
    # Envoyer une métrique CloudWatch d'échec
    aws cloudwatch put-metric-data \
        --namespace "Custom/Cinephoria" \
        --metric-name "BackupSuccess" \
        --value 0 \
        --dimensions Database=PostgreSQL,Environment=$ENVIRONMENT
    
    exit 1
fi

echo "🎉 PostgreSQL backup completed successfully!"
```

#### [`scripts/restore-postgres.sh`](scripts/restore-postgres.sh)

```bash
#!/bin/bash
# Script de restauration PostgreSQL depuis S3

set -e

ENVIRONMENT=${1:-production}
BACKUP_FILE=${2:-latest}
S3_BUCKET="cinephoria-backups-$(aws sts get-caller-identity --query Account --output text)"

echo "🔄 Starting PostgreSQL restore for $ENVIRONMENT..."

if [ "$BACKUP_FILE" = "latest" ]; then
    echo "🔍 Finding latest backup..."
    BACKUP_FILE=$(aws s3 ls "s3://${S3_BUCKET}/postgres/${ENVIRONMENT}/" \
        | sort | tail -n 1 | awk '{print $4}')
    echo "📦 Using backup: $BACKUP_FILE"
fi

S3_PATH="postgres/${ENVIRONMENT}/${BACKUP_FILE}"
LOCAL_FILE="/tmp/${BACKUP_FILE}"

# Télécharger depuis S3
echo "⬇️  Downloading backup from S3..."
aws s3 cp "s3://${S3_BUCKET}/${S3_PATH}" "$LOCAL_FILE"

# Variables de base de données
if [ "$ENVIRONMENT" = "production" ]; then
    DB_NAME="CinephoriaDB_Production"
elif [ "$ENVIRONMENT" = "staging" ]; then
    DB_NAME="CinephoriaDB_Staging"
fi

DB_PASSWORD=$(cat /opt/cinephoria/.postgres_password)

# Arrêter l'application
echo "⏹️  Stopping application..."
docker-compose -f "/opt/cinephoria/docker-compose.${ENVIRONMENT}.yml" stop backend

# Restaurer la base de données
echo "🔄 Restoring database..."
# Décompresser et restaurer
gunzip -c "$LOCAL_FILE" | PGPASSWORD="$DB_PASSWORD" pg_restore \
    -h localhost \
    -p 5432 \
    -U postgres \
    -d "$DB_NAME" \
    --verbose \
    --clean \
    --if-exists

# Redémarrer l'application
echo "🔄 Starting application..."
docker-compose -f "/opt/cinephoria/docker-compose.${ENVIRONMENT}.yml" start backend

# Nettoyer
rm -f "$LOCAL_FILE"

echo "✅ PostgreSQL restore completed successfully!"
```

### Configuration MongoDB Atlas

#### Conseils Backup MongoDB Atlas Free Tier

```yaml
# Configuration recommandée pour MongoDB Atlas Free Tier
Backup:
  - Snapshots automatiques: Tous les 6 heures
  - Rétention: 2 jours (limitation Free Tier)
  - Export manuel: JSON/BSON via mongodump
  - Fréquence export manuel: Hebdomadaire

# Script d'export manuel
mongodump --uri="$MONGODB_URI" --out="/tmp/mongodb-backup-$(date +%Y%m%d)"
```

### Configuration S3 Lifecycle

#### [`modules/s3-backup/main.tf`](CinephoriaInfra/modules/s3-backup/main.tf)

```hcl
resource "aws_s3_bucket" "backups" {
  bucket = "cinephoria-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "postgres-backups"
    status = "Enabled"

    filter {
      prefix = "postgres/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
```

## 🔐 5. Sécurité & Qualité

### Configuration SonarCloud

#### [`sonar-project.properties`](sonar-project.properties)

```properties
# Configuration SonarCloud pour Cinephoria
sonar.organization=your-organization
sonar.projectKey=your-org_cinephoria

# Backend .NET
sonar.sources=CinephoriaBackEnd
sonar.cs.dotcover.reportsPaths=coverage/dotcover.html
sonar.coverage.exclusions=**/Migrations/**,**/DTOs/**,**/Models/**

# Frontend Angular
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.tests=src/app
sonar.test.inclusions=**/*.spec.ts

# Qualité de code
sonar.codeSmells.threshold=100
sonar.bugs.threshold=50
sonar.vulnerabilities.threshold=10
sonar.coverage.threshold=80
```

### Configuration Trivy & Security Scanning

#### [`.github/workflows/security-scan.yml`](.github/workflows/security-scan.yml)

```yaml
name: Security Scan

on:
  push:
    branches: [ develop, main ]
  pull_request:
    branches: [ develop, main ]
  schedule:
    - cron: '0 2 * * 1' # Weekly on Monday at 2 AM

jobs:
  trivy-scan:
    name: Vulnerability Scan
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
        severity: 'CRITICAL,HIGH'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-results.sarif'

  dependency-scan:
    name: Dependency Scan
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'

    - name: Audit JavaScript dependencies
      working-directory: Cinephoria-web
      run: |
        npm audit --audit-level high
        npm audit fix

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '8.0.x'

    - name: Audit .NET dependencies
      working-directory: CinephoriaBackEnd
      run: dotnet list package --vulnerable

  codeql-analysis:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v3
      with:
        languages: csharp, javascript

    - name: Autobuild
      uses: github/codeql-action/autobuild@v3

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v3
```

### Configuration Dependabot

#### [`.github/dependabot.yml`](.github/dependabot.yml)

```yaml
version: 2
updates:
  # Backend .NET dependencies
  - package-ecosystem: "nuget"
    directory: "/CinephoriaBackEnd"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "backend"

  # Frontend npm dependencies
  - package-ecosystem: "npm"
    directory: "/Cinephoria-web"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "frontend"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"

  # Docker dependencies
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "docker"
```

### Configuration IAM Least Privilege

#### [`modules/iam-least-privilege/main.tf`](CinephoriaInfra/modules/iam-least-privilege/main.tf)

```hcl
# Rôle EC2 avec permissions minimales
resource "aws_iam_role" "ec2_role" {
  name = "cinephoria-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "cinephoria-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 🧪 6. Tests Automatisés

### Tests de Performance Artillery

#### [`artillery/prod-load-test.yml`](artillery/prod-load-test.yml)

```yaml
config:
  target: 'https://api.cinephoria.eu'
  phases:
    - duration: 60
      arrivalRate: 10
      name: Warm up
    - duration: 120
      arrivalRate: 50
      name: Spike test
  payload:
    path: "data/users.csv"
    fields:
      - "userId"
    order: "random"
  plugins:
    ensure: {}
    apdex: {}
  apdex:
    threshold: 1000

scenarios:
  - name: "Health Check"
    flow:
      - get:
          url: "/health/ready"
          capture:
            - json: "$.status"
              as: "health_status"

  - name: "Movie List"
    flow:
      - get:
          url: "/api/movies"
          capture:
            - json: "$.movies[0].id"
              as: "movieId"

  - name: "Movie Details"
    flow:
      - get:
          url: "/api/movies/{{ movieId }}"

  - name: "Create Reservation"
    flow:
      - post:
          url: "/api/reservations"
          json:
            movieId: "{{ movieId }}"
            showtime: "2024-01-01T20:00:00Z"
            seats: 2
          capture:
            - json: "$.reservationId"
              as: "reservationId"
```

#### [`.github/workflows/performance-test.yml`](.github/workflows/performance-test.yml)

```yaml
name: Performance Tests

on:
  schedule:
    - cron: '0 2 * * *' # Daily at 2 AM
  workflow_dispatch:

jobs:
  performance-test:
    name: Run Performance Tests
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'

    - name: Install Artillery
      run: npm install -g artillery

    - name: Run production load test
      run: |
        artillery run artillery/prod-load-test.yml \
          --output artillery-report.json
        
        artillery report artillery-report.json

    - name: Upload performance report
      uses: actions/upload-artifact@v4
      with:
        name: performance-report
        path: artillery-report.json

    - name: Check performance thresholds
      run: |
        artillery run artillery/prod-load-test.yml \
          --config artillery/thresholds.yml
```

### Vérification des Backups

#### [`.github/workflows/backup-verification.yml`](.github/workflows/backup-verification.yml)

```yaml
name: Backup Verification

on:
  schedule:
    - cron: '0 6 * * *' # Daily at 6 AM

jobs:
  verify-backups:
    name: Verify Backups
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Check PostgreSQL backups
      run: |
        # Vérifier l'existence du dernier backup
        aws s3 ls s3://cinephoria-backups-${AWS_ACCOUNT_ID}/postgres/production/ \
          | tail -n 1 \
          | awk '{print $4, $5}'

    - name: Check backup size
      run: |
        LATEST_BACKUP=$(aws s3 ls s3://cinephoria-backups-${AWS_ACCOUNT_ID}/postgres/production/ \
          | sort | tail -n 1 | awk '{print $4}')
        
        if [ -z "$LATEST_BACKUP" ]; then
          echo "❌ No backup found"
          exit 1
        fi
        
        BACKUP_SIZE=$(aws s3 ls s3://cinephoria-backups-${AWS_ACCOUNT_ID}/postgres/production/$LATEST_BACKUP \
          | awk '{print $3}')
        
        echo "Backup size: $((BACKUP_SIZE / 1024 / 1024)) MB"
        
        # Vérifier que le backup a une taille raisonnable
        if [ $BACKUP_SIZE -lt 1000000 ]; then # 1MB
          echo "❌ Backup too small"
          exit 1
        fi

    - name: Send verification result
      if: always()
      run: |
        if [ $? -eq 0 ]; then
          echo "✅ Backup verification successful"
        else
          echo "❌ Backup verification failed"
        fi
```

## 📘 7. Runbooks & SLO

### SLI/SLO Recommandés

#### [`docs/slos.md`](docs/slos.md)

```markdown
# Service Level Objectives - Cinephoria

## 📊 SLIs (Service Level Indicators)

### API Availability
- **SLI**: Proportion de requêtes HTTP réussies
- **Mesure**: `http_requests_total{status!~"5.."}` / `http_requests_total`
- **Cible**: 99.5%

### API Latency  
- **SLI**: Latence du 95ème percentile
- **Mesure**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- **Cible**: < 1 seconde

### Database Availability
- **SLI**: Connectivité PostgreSQL réussie
- **Mesure**: Health check endpoint
- **Cible**: 99.9%

### Frontend Availability
- **SLI**: Pages chargées avec succès
- **Mesure**: Synthetic monitoring
- **Cible**: 99%

## 🎯 SLOs (Service Level Objectives)

### API SLO
- **Disponibilité**: 99.5% sur 30 jours
- **Latence**: 95% des requêtes < 1s sur 30 jours
- **Budget d'erreur**: 0.5% (21.6 heures d'indisponibilité/mois)

### Database SLO  
- **Disponibilité**: 99.9% sur 30 jours
- **Budget d'erreur**: 0.1% (4.32 heures d'indisponibilité/mois)

### Frontend SLO
- **Disponibilité**: 99% sur 30 jours
- **Budget d'erreur**: 1% (7.2 heures d'indisponibilité/mois)

## 📈 Calcul du Budget d'Erreur

```
Budget d'erreur = (100 - SLO) / 100 * Période

Exemple API (99.5% sur 30 jours):
Budget = 0.5% × 720 heures = 3.6 heures/mois
```

## 🔄 Revue des SLOs
- Revue trimestrielle des SLOs
- Ajustement basé sur les métriques réelles
- Communication avec les stakeholders
```

### Runbook Incident P1

#### [`docs/runbooks/p1-incident.md`](docs/runbooks/p1-incident.md)

```markdown
# Runbook Incident P1 - Service Critique

## 🚨 Définition Incident P1
- API complètement indisponible (> 5 minutes)
- Perte de données
- Sécurité compromise
- Impact utilisateurs > 50%

## 👥 Équipe de Réponse
- **Primary On-call**: [Nom]
- **Secondary**: [Nom] 
- **Tech Lead**: [Nom]
- **Product Manager**: [Nom]

## 🔧 Actions Immédiates

### 1. Évaluation (5 premières minutes)
```bash
# Vérifier la santé des services
curl -f https://api.cinephoria.eu/health/ready
curl -f https://www.cinephoria.eu

# Vérifier CloudWatch Alarms
aws cloudwatch describe-alarms --state-value ALARM

# Vérifier les logs récents
aws logs filter-log-events \
  --log-group-name /cinephoria/api-production \
  --start-time $(date -d '1 hour ago' +%s) \
  --filter-pattern "ERROR"
```

### 2. Communication
- [ ] Notifier l'équipe via Slack (#incidents)
- [ ] Mettre à jour la page de statut
- [ ] Informer le Product Manager

### 3. Diagnostic Rapide
```bash
# SSH vers l'instance EC2
ssh ec2-user@$EC2_IP

# Vérifier les containers Docker
docker ps -a
docker logs cinephoria-backend-production

# Vérifier les ressources
free -h
df -h
top
```

### 4. Actions de Restauration
**Option A: Redémarrage des services**
```bash
cd /opt/cinephoria
docker-compose -f docker-compose.production.yml restart
```

**Option B: Rollback de version**
```bash
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d
```

**Option C: Restauration depuis backup**
```bash
./scripts/restore-postgres.sh production latest
```

## 📋 Checklist Post-Incident
- [ ] Service restauré et stable
- [ ] Communication aux utilisateurs
- [ ] Documentation de l'incident
- [ ] Post-mortem dans les 48h
- [ ] Actions correctives identifiées
```

### Template Incident

#### [`docs/templates/incident-template.md`](docs/templates/incident-template.md)

```markdown
# Incident Report - [Titre]

## 📋 Informations de Base
- **Date**: [Date]
- **Heure début**: [HH:MM]  
- **Heure fin**: [HH:MM]
- **Durée**: [X heures Y minutes]
- **Niveau**: P1/P2/P3
- **Services impactés**: [Liste]

## 👥 Équipe
- **Incident Commander**: [Nom]
- **Technical Lead**: [Nom]
- **Communications**: [Nom]
- **Documentation**: [Nom]

## 📖 Chronologie
| Heure | Action | Personne |
|-------|--------|----------|
| HH:MM | [Description] | [Nom] |
| HH:MM | [Description] | [Nom] |

## 🎯 Impact
- **Utilisateurs affectés**: [Nombre/Percentage]
- **Fonctionnalités impactées**: [Liste]
- **Perte de données**: [Oui/Non - Détails]

## 🔍 Cause Racine
[Description détaillée de la cause fondamentale]

## 🛠️ Actions Correctives
### Immédiates
- [ ] [Action réalisée]
- [ ] [Action réalisée]

### À Moyen Terme  
- [ ] [Action planifiée - Date]
- [ ] [Action planifiée - Date]

### À Long Terme
- [ ] [Action planifiée - Date]
- [ ] [Action planifiée - Date]

## 📈 Métriques d'Impact
- **Temps de détection**: [X minutes]
- **Temps de résolution**: [X minutes]
- **MTTR**: [X minutes]
- **SLO impact**: [Détails]

## 🎓 Apprentissages
- Ce qui a bien fonctionné
- Ce qui pourrait être amélioré
- Actions préventives

## 📝 Actions de Suivi
| Action | Responsable | Échéance | Statut |
|--------|-------------|----------|--------|
| [Action] | [Nom] | [Date] | [ ] |
| [Action] | [Nom] | [Date] | [ ] |

**Date de revue**: [Date]
**Prochaine revue**: [Date]
```

## 🧾 Recommandations Coût/Performance

### Optimisations Low-Cost

```yaml
# Configuration CloudWatch Logs
Logs:
  Retention: 
    - Production: 30 jours
    - Staging: 7 jours
    - Development: 1 jour
  Compression: GZIP automatique
  Metric Filters: Seulement les métriques essentielles

# Configuration S3
Storage:
  PostgreSQL Backups:
    - Standard IA après 30 jours
    - Glacier après 90 jours
    - Suppression après 1 an
  CloudFront Logs:
    - Compression activée
    - Suppression après 30 jours

# Configuration EC2
Instance:
  - Type: t3.micro (Free Tier)
  - EBS Optimization: Activée
  - Monitoring détaillé: Désactivé (coût)
  - CloudWatch Agent: Métriques système seulement

# Alerting
Alarms:
  - Seulement les alertes critiques
  - Période: 5 minutes (au lieu de 1)
  - Seuils conservateurs
  - Pas d'alarmes de basse priorité
```

Ce plan fournit une solution complète de monitoring, sécurité et optimisation pour Cinephoria avec une approche low-cost tout en maintenant la qualité de service.