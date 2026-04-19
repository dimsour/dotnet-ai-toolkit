---
name: deploy
description: Deployment patterns — Dockerfile, Kubernetes, Azure App Service, IIS, config hierarchy, health checks, graceful shutdown, data protection. Auto-loads for Dockerfile/k8s/appsettings work.
effort: medium
---

# deploy

Deployment patterns for .NET 8–11.

## Iron Laws (deploy)

- Secrets NOT in `appsettings.json` (Iron Law #28)
- `ASPNETCORE_ENVIRONMENT=Production` in prod
- Non-root container user
- Resource limits set in k8s
- Data Protection keys persisted across replicas
- Readiness + liveness probes distinct

## Dockerfile — Multi-stage, chiseled

```dockerfile
# syntax=docker/dockerfile:1.7
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApp.sln", "./"]
COPY ["src/MyApp.Api/MyApp.Api.csproj", "src/MyApp.Api/"]
COPY ["src/MyApp.Core/MyApp.Core.csproj", "src/MyApp.Core/"]
RUN dotnet restore
COPY . .
RUN dotnet publish src/MyApp.Api/MyApp.Api.csproj \
    -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0-noble-chiseled AS final
WORKDIR /app
USER $APP_UID
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "MyApp.Api.dll"]
```

`.dockerignore`:

```
**/bin/
**/obj/
**/*.user
.git/
.vs/
appsettings.Development.json
appsettings.Local.json
secrets/
```

## Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: myapp }
spec:
  replicas: 3
  selector: { matchLabels: { app: myapp } }
  template:
    metadata: { labels: { app: myapp } }
    spec:
      terminationGracePeriodSeconds: 60
      securityContext:
        runAsNonRoot: true
        runAsUser: 1654       # $APP_UID from chiseled
        fsGroup: 1654
      containers:
        - name: api
          image: myregistry/myapp:1.0.0
          imagePullPolicy: IfNotPresent
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities: { drop: [ALL] }
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits:   { cpu: 500m, memory: 512Mi }
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: Production
          envFrom:
            - secretRef: { name: myapp-secrets }
          ports: [{ containerPort: 8080 }]
          livenessProbe:
            httpGet: { path: /health/live, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet: { path: /health/ready, port: 8080 }
            initialDelaySeconds: 5
            periodSeconds: 5
          lifecycle:
            preStop:
              exec: { command: ["/bin/sh", "-c", "sleep 5"] }
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

## Health Checks

```csharp
services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>("db", tags: ["ready"])
    .AddRedis(redisConn, tags: ["ready"]);

app.MapHealthChecks("/health/live", new()
{
    Predicate = _ => false  // only process check, no dependencies
});

app.MapHealthChecks("/health/ready", new()
{
    Predicate = c => c.Tags.Contains("ready")
});
```

## Graceful Shutdown

```csharp
builder.Services.Configure<HostOptions>(o =>
    o.ShutdownTimeout = TimeSpan.FromSeconds(30));
```

Background services respect `stoppingToken`. Keep drains short so pod
terminates before k8s SIGKILL.

## Data Protection (multi-replica)

```csharp
services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(blobUri, new DefaultAzureCredential())
    .ProtectKeysWithAzureKeyVault(keyId, new DefaultAzureCredential())
    .SetApplicationName("MyApp");
```

Without this, cookie auth breaks when the load balancer routes to a
different replica.

## Configuration Hierarchy

Later overrides earlier:

1. `appsettings.json`
2. `appsettings.{Environment}.json`
3. User Secrets (Development only)
4. Environment variables
5. Command-line args

Env var conversion: `MyApp:Db:ConnectionString` ↔
`MyApp__Db__ConnectionString`.

## Azure App Service

- Connection Strings collection in App Settings → bound as
  `ConnectionStrings:{Name}`
- App Settings → env vars (Windows hosts: `SET` style; Linux: `export`)
- Health check path in App Service: set to `/health/ready`

## CI/CD (GitHub Actions)

```yaml
- uses: actions/setup-dotnet@v4
  with: { dotnet-version: 8.0.x }
- run: dotnet restore --locked-mode
- run: dotnet build --no-restore -c Release /warnaserror
- run: dotnet test --no-build -c Release --logger trx
- run: dotnet list package --vulnerable --include-transitive
  continue-on-error: false
```

## References

- `${CLAUDE_SKILL_DIR}/references/docker.md` — chiseled images, AOT,
  size optimization
- `${CLAUDE_SKILL_DIR}/references/kubernetes.md` — probes, security,
  HPA, PDB
- `${CLAUDE_SKILL_DIR}/references/config.md` — config hierarchy, env
  vars, secrets mounts
- `${CLAUDE_SKILL_DIR}/references/azure.md` — App Service, Container
  Apps, Functions specifics
- `${CLAUDE_SKILL_DIR}/references/iis.md` — web.config, AspNetCoreModule
- `${CLAUDE_SKILL_DIR}/references/data-protection.md` — multi-replica
  setup
- `${CLAUDE_SKILL_DIR}/references/graceful-shutdown.md` — signal handling,
  drain patterns

## Anti-patterns

- Running container as root
- `latest` tag in prod manifests
- Single `/health` gating both liveness and readiness (restart storms on
  transient DB blips)
- No Data Protection persistence → cookie breakage on replica switch
- Secrets in committed appsettings (Iron Law #28)
