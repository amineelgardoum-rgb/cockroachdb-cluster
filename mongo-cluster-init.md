# MongoDB Sharded Cluster Initialization Guide

## Overview
This guide will help you initialize a MongoDB sharded cluster with:
- 3 Config Server replica set members
- 3 Shards, each with 3 replica set members
- 3 Mongos routers
- Prometheus + Grafana monitoring
- n8n workflow automation

## Prerequisites
- Docker and Docker Compose installed
- The `docker-compose.yml` file in your working directory
- The `prometheus.yml` configuration file

## Step 1: Start the Cluster

```bash
docker-compose up -d
```

Wait 30-60 seconds for all containers to start.

## Step 2: Initialize Config Server Replica Set

Connect to the config server:
```bash
docker exec -it configsvr mongosh --port 27017
```

Initialize the replica set:
```javascript
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr:27017" },
    { _id: 1, host: "configsvr1:27017" },
    { _id: 2, host: "configsvr2:27017" }
  ]
});
```

Wait for the replica set to elect a primary, then exit:
```javascript
exit
```

## Step 3: Initialize Shard 1 Replica Set

Connect to shard1:
```bash
docker exec -it shard1 mongosh --port 27018
```

Initialize the replica set:
```javascript
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27018" },
    { _id: 1, host: "shard1-1:27018" },
    { _id: 2, host: "shard1-2:27018" }
  ]
});
```

Exit:
```javascript
exit
```

## Step 4: Initialize Shard 2 Replica Set

Connect to shard2:
```bash
docker exec -it shard2 mongosh --port 27019
```

Initialize the replica set:
```javascript
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27019" },
    { _id: 1, host: "shard2-1:27019" },
    { _id: 2, host: "shard2-2:27019" }
  ]
});
```

Exit:
```javascript
exit
```

## Step 5: Initialize Shard 3 Replica Set

Connect to shard3:
```bash
docker exec -it shard3 mongosh --port 27029
```

Initialize the replica set:
```javascript
rs.initiate({
  _id: "shard3ReplSet",
  members: [
    { _id: 0, host: "shard3:27029" },
    { _id: 1, host: "shard3-1:27029" },
    { _id: 2, host: "shard3-2:27029" }
  ]
});
```

Exit:
```javascript
exit
```

## Step 6: Add Shards to the Cluster

Connect to mongos:
```bash
docker exec -it mongos mongosh --port 27020
```

Add all three shards:
```javascript
sh.addShard("shard1ReplSet/shard1:27018,shard1-1:27018,shard1-2:27018");
sh.addShard("shard2ReplSet/shard2:27019,shard2-1:27019,shard2-2:27019");
sh.addShard("shard3ReplSet/shard3:27029,shard3-1:27029,shard3-2:27029");
```

Verify the cluster status:
```javascript
sh.status();
```

Exit:
```javascript
exit
```

## Step 7: Enable Sharding on a Database (Example)

Connect to mongos:
```bash
docker exec -it mongos mongosh --port 27020
```

Enable sharding for a database (replace `myDatabase` with your database name):
```javascript
sh.enableSharding("myDatabase");
```

Shard a collection (replace with your database and collection):
```javascript
sh.shardCollection("myDatabase.myCollection", { _id: "hashed" });
```

Exit:
```javascript
exit
```

## Step 8: Access Monitoring and Tools

### Prometheus
- URL: http://localhost:9090
- Check targets at: http://localhost:9090/targets

### Grafana
- URL: http://localhost:3000
- Username: `admin`
- Password: `YourNewPassword123`

**Configure Grafana:**
1. Add Prometheus as a data source: http://prometheus:9090
2. Import MongoDB dashboard (Dashboard ID: 2583 or create custom)

### n8n
- URL: http://localhost:5678
- Database: MongoDB (already configured to use the cluster)

### MongoDB Exporter Metrics
- URL: http://localhost:9216/metrics

## Verification Commands

Check replica set status:
```bash
docker exec -it configsvr mongosh --port 27017 --eval "rs.status()"
docker exec -it shard1 mongosh --port 27018 --eval "rs.status()"
docker exec -it shard2 mongosh --port 27019 --eval "rs.status()"
docker exec -it shard3 mongosh --port 27029 --eval "rs.status()"
```

Check cluster status:
```bash
docker exec -it mongos mongosh --port 27020 --eval "sh.status()"
```

Check all containers are running:
```bash
docker-compose ps
```

## Connection Strings

### Application Connection (via Mongos)
```
mongodb://localhost:27033/
mongodb://localhost:27034/
mongodb://localhost:27035/
```

Or use all mongos instances:
```
mongodb://localhost:27033,localhost:27034,localhost:27035/
```

### Internal Connection (from other containers)
```
mongodb://mongos:27020/
mongodb://mongos2:27020/
mongodb://mongos3:27020/
```

## Troubleshooting

### Check container logs:
```bash
docker logs configsvr
docker logs shard1
docker logs mongos
```

### Restart the cluster:
```bash
docker-compose down
docker-compose up -d
```

### Full reset (⚠️ deletes all data):
```bash
docker-compose down -v
docker-compose up -d
```

Then re-run initialization steps 2-6.

## Common Operations

### Add a new database and enable sharding:
```javascript
use newDatabase
db.createCollection("newCollection")
sh.enableSharding("newDatabase")
sh.shardCollection("newDatabase.newCollection", { shardKey: 1 })
```

### Check shard distribution:
```javascript
db.newCollection.getShardDistribution()
```

### View chunk distribution:
```javascript
use config
db.chunks.find().pretty()
```

## Security Note

⚠️ This setup has no authentication enabled. For production:
1. Enable authentication on all MongoDB instances
2. Create admin users
3. Configure keyfile for replica set authentication
4. Update connection strings with credentials
5. Change default Grafana password
6. Enable n8n authentication

## Next Steps

1. Configure backups for your data
2. Set up monitoring alerts in Grafana
3. Tune shard key selection based on your data access patterns
4. Configure n8n workflows to interact with your MongoDB cluster
5. Implement proper authentication and security measures