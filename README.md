# MongoDB Sharded Cluster - Medical Database

## 📋 Overview

This project implements a production-ready MongoDB sharded cluster for managing medical data at scale. The architecture supports 3 million patients, 20 million consultations, and integrates with n8n for workflow automation.

**Quick Stats:**

- 🏥 3 Hospitals
- 👨‍⚕️ 5,000 Doctors
- 👥 3,000,000 Patients
- 📝 20,000,000 Consultations
- 🔧 3 Shards with replica sets
- 🚀 3 Mongos routers for high availability

## Architecture

### Architecture Diagram

![MongoDB Sharded Cluster Architecture](./assets/architecture.png)

*Complete architecture diagram showing config servers, shards, mongos routers, and n8n integration*

### Cluster Components

- **3 Config Servers** (configsvr, configsvr1, configsvr2)

  - Replica Set: `configReplSet`
  - Ports: 27017-27019
  - Stores cluster metadata and configuration
- **3 Shards** with replica sets

  - **Shard 1** (shard1ReplSet): Ports 27020-27022
  - **Shard 2** (shard2ReplSet): Ports 27023-27025
  - **Shard 3** (shard3ReplSet): Ports 27026-27028
  - Each shard has 3 replicas for high availability
- **3 Mongos Routers**

  - Ports: 27030-27032
  - Route queries to appropriate shards
  - Load balance across the cluster
- **n8n Workflow Automation**

  - Port: 5678
  - Connected to MongoDB via mongos router
  - Database: `n8n`

## Data Model

### Collections

#### 1. Hospitals

```json
{
  "hospital_id": 1,
  "name": "Hospital 1",
  "created_at": "2025-12-09T10:30:00"
}
```

- **Shard Key**: `hospital_id` (hashed)
- **Total Records**: 3

#### 2. Doctors

```json
{
  "doctor_id": 1,
  "name": "Dr. John Smith",
  "hospital_id": 2,
  "specialty": "Cardiology",
  "created_at": "2025-12-09T10:30:00"
}
```

- **Shard Key**: `doctor_id` (hashed)
- **Total Records**: 5,000

#### 3. Patients

```json
{
  "patient_id": 1,
  "name": "Jane Doe",
  "age": 45,
  "hospital_id": 1,
  "created_at": "2025-12-09T10:30:00"
}
```

- **Shard Key**: `patient_id` (hashed)
- **Total Records**: 3,000,000

#### 4. Consultations

```json
{
  "consultation_id": 1,
  "hospital_id": 2,
  "patient_id": 15000,
  "doctor_id": 250,
  "date": "2022-05-15T14:30:00",
  "notes": "Patient has fever. Diagnosed with flu. Treated using Rest.",
  "created_at": "2025-12-09T10:30:00"
}
```

- **Shard Key**: `consultation_id` (hashed)
- **Total Records**: 20,000,000

## Setup Instructions

### 1. Start the Cluster

```bash
docker-compose up -d
```

This command starts all services:

- Config servers
- Shard servers
- Mongos routers
- n8n instance

### 2. Initialize Replica Sets

Wait for containers to be healthy, then initialize each replica set:

```bash
# Initialize Config Server Replica Set
docker exec configsvr mongosh --port 27017 --eval '
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr:27017" },
    { _id: 1, host: "configsvr1:27017" },
    { _id: 2, host: "configsvr2:27017" }
  ]
})'

# Initialize Shard 1 Replica Set
docker exec shard1 mongosh --port 27018 --eval '
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27018" },
    { _id: 1, host: "shard1-1:27018" },
    { _id: 2, host: "shard1-2:27018" }
  ]
})'

# Initialize Shard 2 Replica Set
docker exec shard2 mongosh --port 27019 --eval '
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27019" },
    { _id: 1, host: "shard2-1:27019" },
    { _id: 2, host: "shard2-2:27019" }
  ]
})'

# Initialize Shard 3 Replica Set
docker exec shard3 mongosh --port 27029 --eval '
rs.initiate({
  _id: "shard3ReplSet",
  members: [
    { _id: 0, host: "shard3:27029" },
    { _id: 1, host: "shard3-1:27029" },
    { _id: 2, host: "shard3-2:27029" }
  ]
})'
```

### 3. Add Shards to Cluster

```bash
docker exec mongos mongosh --port 27017 --eval '
sh.addShard("shard1ReplSet/shard1:27018,shard1-1:27018,shard1-2:27018");
sh.addShard("shard2ReplSet/shard2:27019,shard2-1:27019,shard2-2:27019");
sh.addShard("shard3ReplSet/shard3:27029,shard3-1:27029,shard3-2:27029");
'
```

### 4. Generate Sample Data

```bash
python main.py
```

This generates:

- `generated_data/hospitals.json` (3 records)
- `generated_data/doctors.json` (5,000 records)
- `generated_data/patients.json` (3,000,000 records)
- `generated_data/consultations.json` (20,000,000 records)

### 5. Configure Sharding

```bash
./shard.sh
```

This script:

- Enables sharding on the `medical` database
- Creates hashed indexes on shard keys
- Configures shard distribution for all collections

## Sharding Strategy

### Hashed Sharding

All collections use **hashed sharding** for even data distribution:

- **Advantages**:

  - Uniform distribution across shards
  - No hot spots from monotonic IDs
  - Automatic balancing
- **Trade-offs**:

  - Range queries require scatter-gather operations
  - Cannot use targeted queries on shard key

### Alternative: Range-Based Sharding

For hospital-based queries, consider range sharding on `hospital_id`:

```javascript
sh.shardCollection("medical.consultations", { hospital_id: 1, consultation_id: 1 })
```

This enables:

- Targeted queries per hospital
- Better performance for hospital-specific analytics
- Reduced cross-shard operations

## Data Import

### Using mongoimport

```bash
# Import hospitals
docker exec -i mongos mongoimport \
  --uri="mongodb://mongos:27017/medical" \
  --collection=hospitals \
  --file=/path/to/hospitals.json \
  --jsonArray

# Import doctors
docker exec -i mongos mongoimport \
  --uri="mongodb://mongos:27017/medical" \
  --collection=doctors \
  --file=/path/to/doctors.json \
  --jsonArray

# Import patients (large file)
docker exec -i mongos mongoimport \
  --uri="mongodb://mongos:27017/medical" \
  --collection=patients \
  --file=/path/to/patients.json \
  --jsonArray

# Import consultations (large file)
docker exec -i mongos mongoimport \
  --uri="mongodb://mongos:27017/medical" \
  --collection=consultations \
  --file=/path/to/consultations.json \
  --jsonArray
```

## Access Points

- **Mongos Router 1**: `localhost:27030`
- **Mongos Router 2**: `localhost:27031`
- **Mongos Router 3**: `localhost:27032`
- **n8n**: `http://localhost:5678`

### Connection String

```
mongodb://mongos:27030,mongos2:27031,mongos3:27032/medical?authSource=admin
```

## Monitoring & Operations

### Check Cluster Status

```bash
docker exec mongos mongosh --port 27017 --eval 'sh.status()'
```

### Check Shard Distribution

```bash
docker exec mongos mongosh --port 27017 --eval '
db = db.getSiblingDB("medical");
db.consultations.getShardDistribution();
'
```

### View Chunk Distribution

```bash
docker exec mongos mongosh --port 27017 --eval '
db = db.getSiblingDB("config");
db.chunks.find({ns: "medical.consultations"}).count();
'
```

## Scaling Considerations

### Horizontal Scaling

To add more shards:

1. Add new shard services to `docker-compose.yml`
2. Initialize replica set for new shard
3. Add shard to cluster: `sh.addShard("newShardReplSet/...")`
4. MongoDB automatically rebalances chunks

### Vertical Scaling

- Increase container resources in Docker
- Add more replicas per shard for read scaling
- Use MongoDB Atlas for managed scaling

## n8n Integration

The n8n instance connects to the cluster for workflow automation:

- **Use Cases**:

  - Automated patient notifications
  - Appointment scheduling
  - Data synchronization
  - Report generation
- **Connection**: Uses mongos router for high availability
- **Database**: Separate `n8n` database for workflows

## File Structure

```
.
├── docker-compose.yml       # Cluster configuration
├── main.py                  # Data generation script
├── shard.sh                 # Sharding setup script
├── .gitignore              # Git ignore rules
└── generated_data/         # Generated JSON files
    ├── hospitals.json
    ├── doctors.json
    ├── patients.json
    └── consultations.json
```

## Troubleshooting

### Container Won't Start

```bash
docker-compose logs <service_name>
docker-compose restart <service_name>
```

### Replica Set Not Initialized

Wait 30-60 seconds after `docker-compose up`, then retry initialization commands.

### Sharding Fails

Ensure all replica sets are initialized and healthy:

```bash
docker exec mongos mongosh --port 27017 --eval 'sh.status()'
```

### Data Import Issues

For large files, increase Docker memory limits and use `--numInsertionWorkers` flag:

```bash
mongoimport --numInsertionWorkers 4 ...
```

## Performance Tips

1. **Index Strategy**: Create compound indexes for frequent queries
2. **Shard Key Selection**: Choose keys with high cardinality
3. **Read Preference**: Use `secondaryPreferred` for read scaling
4. **Write Concern**: Adjust based on consistency requirements
5. **Chunk Size**: Default 64MB, tune based on workload

## Security Notes

⚠️ **Current Configuration**: No authentication enabled (--noauth)

### Production Recommendations:

1. Enable authentication
2. Use TLS/SSL for connections
3. Implement role-based access control (RBAC)
4. Enable audit logging
5. Regular backup strategy

## Next Steps

1. Import generated data using mongoimport
2. Create additional indexes for query optimization
3. Set up monitoring (Prometheus/Grafana stack available in comments)
4. Configure n8n workflows
5. Implement backup strategy
6. Enable security features for production
