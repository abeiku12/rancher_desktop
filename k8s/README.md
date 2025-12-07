# Self-Hosted Kubernetes Cluster on Rancher Desktop

A production-ready 3-tier application with full monitoring stack for Rancher Desktop.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes Cluster                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        MONITORING NAMESPACE                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │  Prometheus │  │   Grafana   │  │    Loki      │  │ Alertmanager │ │ │
│  │  │  :30090     │  │   :30030    │  │   (logs)     │  │   :30093     │ │ │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  └──────────────┘ │ │
│  │                          │                │                            │ │
│  │                          └────────┬───────┘                            │ │
│  └───────────────────────────────────│────────────────────────────────────┘ │
│                                      │ Scrape Metrics                        │
│  ┌───────────────────────────────────│────────────────────────────────────┐ │
│  │                        PRODUCTION NAMESPACE                             │ │
│  │                                   │                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │  │                     FRONTEND TIER (Web)                          │   │ │
│  │  │  ┌─────────────┐  ┌─────────────┐                               │   │ │
│  │  │  │   Nginx     │  │   Nginx     │    NodePort :30080            │   │ │
│  │  │  │  (replica)  │  │  (replica)  │    HPA: 2-5 replicas          │   │ │
│  │  │  └─────────────┘  └─────────────┘                               │   │ │
│  │  └──────────────────────────┬──────────────────────────────────────┘   │ │
│  │                             │                                           │ │
│  │  ┌──────────────────────────▼──────────────────────────────────────┐   │ │
│  │  │                     BACKEND TIER (API)                           │   │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │   │ │
│  │  │  │  Node.js    │  │  Node.js    │  │  Node.js    │              │   │ │
│  │  │  │   API       │  │   API       │  │   API       │              │   │ │
│  │  │  │ (replica)   │  │ (replica)   │  │ (replica)   │              │   │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘              │   │ │
│  │  │                    HPA: 3-10 replicas                            │   │ │
│  │  └──────────────────────────┬──────────────────────────────────────┘   │ │
│  │                             │                                           │ │
│  │  ┌──────────────────────────▼──────────────────────────────────────┐   │ │
│  │  │                    DATABASE TIER                                 │   │ │
│  │  │  ┌─────────────────────┐    ┌─────────────────────┐             │   │ │
│  │  │  │     PostgreSQL      │    │       Redis         │             │   │ │
│  │  │  │  (StatefulSet)      │    │     (Cache)         │             │   │ │
│  │  │  │   + pg_exporter     │    │   + redis_exporter  │             │   │ │
│  │  │  └─────────────────────┘    └─────────────────────┘             │   │ │
│  │  └─────────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Rancher Desktop** installed and running (Linux container mode)
2. **kubectl** configured and connected to Rancher Desktop's Kubernetes cluster
3. At least **8GB RAM** and **4 CPU cores** allocated to Rancher Desktop

## Directory Structure

```
k8s/
├── namespace.yaml              # Namespace definitions
├── ingress.yaml               # Ingress resources
├── network-policies.yaml      # Network policies & resource quotas
├── deploy.sh                  # Deployment script
├── monitoring/
│   ├── prometheus-config.yaml # Prometheus configuration
│   ├── prometheus.yaml        # Prometheus deployment
│   ├── grafana.yaml          # Grafana deployment
│   ├── alertmanager.yaml     # Alertmanager deployment
│   └── loki-promtail.yaml    # Loki & Promtail for logging
└── app/
    ├── database/
    │   ├── postgres.yaml     # PostgreSQL StatefulSet
    │   └── redis.yaml        # Redis deployment
    ├── backend/
    │   └── backend.yaml      # Node.js API deployment
    └── frontend/
        └── frontend.yaml     # Nginx + SPA frontend
```

## Quick Start

### 1. Deploy Everything

```bash
# Make the script executable
chmod +x k8s/deploy.sh

# Deploy the entire stack
./k8s/deploy.sh deploy
```

### 2. Check Status

```bash
./k8s/deploy.sh status
```

### 3. Cleanup

```bash
./k8s/deploy.sh cleanup
```

## Manual Deployment

If you prefer to deploy components individually:

```bash
# 1. Create namespaces
kubectl apply -f k8s/namespace.yaml

# 2. Deploy monitoring stack
kubectl apply -f k8s/monitoring/

# 3. Deploy database tier
kubectl apply -f k8s/app/database/

# 4. Wait for databases
kubectl wait --for=condition=ready pod -l app=postgres -n production --timeout=180s
kubectl wait --for=condition=ready pod -l app=redis -n production --timeout=120s

# 5. Deploy backend
kubectl apply -f k8s/app/backend/

# 6. Deploy frontend
kubectl apply -f k8s/app/frontend/

# 7. Deploy network policies
kubectl apply -f k8s/network-policies.yaml

# 8. Deploy ingress (optional)
kubectl apply -f k8s/ingress.yaml
```

## Access Information

### Application
| Service | URL | Description |
|---------|-----|-------------|
| Frontend | http://localhost:30080 | Main application UI |

### Monitoring
| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:30030 | admin / GrafanaAdmin123! |
| Prometheus | http://localhost:30090 | N/A |
| Alertmanager | http://localhost:30093 | N/A |

### Using Ingress (Optional)

Add to `/etc/hosts`:
```
127.0.0.1 app.local grafana.local prometheus.local alertmanager.local
```

Then access via:
- http://app.local
- http://grafana.local
- http://prometheus.local
- http://alertmanager.local

## Components

### Frontend Tier
- **Nginx 1.25** serving a responsive SPA
- Proxies API requests to backend
- Gzip compression enabled
- Security headers configured
- HPA: 2-5 replicas
- Prometheus metrics via nginx-exporter

### Backend Tier
- **Node.js 20** Express API
- PostgreSQL connection pooling
- Redis caching layer
- Rate limiting (100 req/15min)
- JWT authentication ready
- Prometheus metrics endpoint
- HPA: 3-10 replicas

### Database Tier
- **PostgreSQL 15** with optimized config
- Automatic schema initialization
- Sample data included
- Prometheus metrics via pg_exporter
- Persistent storage (10Gi)

- **Redis 7** for caching
- AOF persistence enabled
- Memory limit: 256MB
- LRU eviction policy
- Prometheus metrics via redis_exporter

### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Visualization & dashboards
- **Loki**: Log aggregation
- **Promtail**: Log collection (DaemonSet)
- **Alertmanager**: Alert routing

## Pre-configured Grafana Dashboards

1. **Kubernetes Cluster Overview**
   - Running pods count
   - CPU usage by namespace
   - Memory usage by namespace

2. **Application Dashboard**
   - HTTP request rate
   - Response latency (p95)
   - Error rate

## Production Features

### Security
- ✅ Non-root containers
- ✅ Read-only root filesystems (where applicable)
- ✅ Network policies for pod-to-pod communication
- ✅ Secrets for sensitive data
- ✅ Security headers (Helmet, CORS)
- ✅ Rate limiting

### High Availability
- ✅ Multiple replicas for stateless services
- ✅ Pod Disruption Budgets (PDB)
- ✅ Pod Anti-affinity rules
- ✅ Rolling update strategy
- ✅ Horizontal Pod Autoscaling (HPA)

### Observability
- ✅ Prometheus metrics for all components
- ✅ Centralized logging with Loki
- ✅ Pre-built Grafana dashboards
- ✅ Alerting rules

### Resource Management
- ✅ Resource requests & limits
- ✅ Resource quotas per namespace
- ✅ Limit ranges

## Useful Commands

```bash
# View all resources
kubectl get all -n production
kubectl get all -n monitoring

# Check pod logs
kubectl logs -f deployment/backend -n production
kubectl logs -f deployment/frontend -n production
kubectl logs -f statefulset/postgres -n production

# Scale deployments
kubectl scale deployment backend --replicas=5 -n production

# Check HPA status
kubectl get hpa -n production

# Port forward to services
kubectl port-forward svc/backend 3000:3000 -n production
kubectl port-forward svc/postgres 5432:5432 -n production

# Connect to PostgreSQL
kubectl exec -it postgres-0 -n production -- psql -U appuser -d production_db

# Check resource usage
kubectl top pods -n production
kubectl top nodes
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Database connection issues
```bash
# Check if PostgreSQL is ready
kubectl exec -it postgres-0 -n production -- pg_isready

# Check Redis
kubectl exec -it deployment/redis -n production -- redis-cli -a RedisP@ssw0rd2024! ping
```

### Backend health check
```bash
kubectl exec -it deployment/frontend -n production -- curl http://backend:3000/health
```

## Customization

### Change database credentials
Edit the secrets in:
- `k8s/app/database/postgres.yaml`
- `k8s/app/database/redis.yaml`

### Adjust resource limits
Edit the resource sections in respective deployment files.

### Add more Grafana dashboards
Add JSON dashboard files to `grafana-dashboards` ConfigMap in `k8s/monitoring/grafana.yaml`.

### Configure alerting
Edit `alertmanager-config` ConfigMap in `k8s/monitoring/alertmanager.yaml` to add notification channels (Slack, Email, PagerDuty).

## License

MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
