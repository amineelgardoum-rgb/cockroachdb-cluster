#!/bin/bash

echo "Waiting for docker to run......."
docker-compose up --build -d

echo "Waiting for the MongoDB nodes to be ready...."
sleep 30

echo "Initializing Config Server Replica Set....."
MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES to initialize config server..."
  
  docker exec configsvr mongosh --port 27017 --eval '
  try {
    let status = rs.status();
    if (status.ok) {
      print("Config server replica set already initialized");
    }
  } catch(e) {
    print("Initializing config server replica set...");
    rs.initiate({
      _id: "configReplSet",
      configsvr: true,
      members: [
        { _id: 0, host: "configsvr:27017" },
        { _id: 1, host: "configsvr1:27017" },
        { _id: 2, host: "configsvr2:27017" }
      ]
    });
    print("Config server replica set initiated!");
  }
  ' && break
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
    echo "Retrying in 10 seconds..."
    sleep 10
  fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Failed to initialize config server after $MAX_RETRIES attempts"
  exit 1
fi

echo "Waiting for config server to elect PRIMARY..."
sleep 15

# Wait for PRIMARY with better error handling
WAIT_COUNT=0
MAX_WAIT=30
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  PRIMARY_COUNT=$(docker exec configsvr mongosh --port 27017 --quiet --eval "
    try {
      let status = rs.status();
      let primaryCount = status.members.filter(m => m.stateStr === 'PRIMARY').length;
      print(primaryCount);
    } catch(e) {
      print('0');
    }
  " 2>/dev/null | tail -1)
  
  if [ "$PRIMARY_COUNT" = "1" ]; then
    echo "Config server PRIMARY elected!"
    break
  fi
  
  echo "Waiting for config server PRIMARY... ($WAIT_COUNT/$MAX_WAIT)"
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
  echo "ERROR: Config server failed to elect PRIMARY"
  docker exec configsvr mongosh --port 27017 --eval "rs.status()"
  exit 1
fi

echo "Initializing Shard1 Replica Set....."
docker exec shard1 mongosh --port 27018 --eval '
try {
  let status = rs.status();
  if (status.ok) {
    print("Shard1 replica set already initialized");
  }
} catch(e) {
  print("Initializing shard1 replica set...");
  rs.initiate({
    _id: "shard1ReplSet",
    members: [
      { _id: 0, host: "shard1:27018" },
      { _id: 1, host: "shard1-1:27018" },
      { _id: 2, host: "shard1-2:27018" }
    ]
  });
  print("Shard1 replica set initiated!");
}
'

echo "Waiting for shard1 to elect PRIMARY..."
sleep 15

WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  PRIMARY_COUNT=$(docker exec shard1 mongosh --port 27018 --quiet --eval "
    try {
      let status = rs.status();
      let primaryCount = status.members.filter(m => m.stateStr === 'PRIMARY').length;
      print(primaryCount);
    } catch(e) {
      print('0');
    }
  " 2>/dev/null | tail -1)
  
  if [ "$PRIMARY_COUNT" = "1" ]; then
    echo "Shard1 PRIMARY elected!"
    break
  fi
  
  echo "Waiting for shard1 PRIMARY... ($WAIT_COUNT/$MAX_WAIT)"
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

echo "Initializing Shard2 Replica Set....."
docker exec shard2 mongosh --port 27019 --eval '
try {
  let status = rs.status();
  if (status.ok) {
    print("Shard2 replica set already initialized");
  }
} catch(e) {
  print("Initializing shard2 replica set...");
  rs.initiate({
    _id: "shard2ReplSet",
    members: [
      { _id: 0, host: "shard2:27019" },
      { _id: 1, host: "shard2-1:27019" },
      { _id: 2, host: "shard2-2:27019" }
    ]
  });
  print("Shard2 replica set initiated!");
}
'

echo "Waiting for shard2 to elect PRIMARY..."
sleep 15

WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  PRIMARY_COUNT=$(docker exec shard2 mongosh --port 27019 --quiet --eval "
    try {
      let status = rs.status();
      let primaryCount = status.members.filter(m => m.stateStr === 'PRIMARY').length;
      print(primaryCount);
    } catch(e) {
      print('0');
    }
  " 2>/dev/null | tail -1)
  
  if [ "$PRIMARY_COUNT" = "1" ]; then
    echo "Shard2 PRIMARY elected!"
    break
  fi
  
  echo "Waiting for shard2 PRIMARY... ($WAIT_COUNT/$MAX_WAIT)"
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

echo "Initializing Shard3 Replica Set....."
docker exec shard3 mongosh --port 27029 --eval '
try {
  let status = rs.status();
  if (status.ok) {
    print("Shard3 replica set already initialized");
  }
} catch(e) {
  print("Initializing shard3 replica set...");
  rs.initiate({
    _id: "shard3ReplSet",
    members: [
      { _id: 0, host: "shard3:27029" },
      { _id: 1, host: "shard3-1:27029" },
      { _id: 2, host: "shard3-2:27029" }
    ]
  });
  print("Shard3 replica set initiated!");
}
'

echo "Waiting for shard3 to elect PRIMARY..."
sleep 15

WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  PRIMARY_COUNT=$(docker exec shard3 mongosh --port 27029 --quiet --eval "
    try {
      let status = rs.status();
      let primaryCount = status.members.filter(m => m.stateStr === 'PRIMARY').length;
      print(primaryCount);
    } catch(e) {
      print('0');
    }
  " 2>/dev/null | tail -1)
  
  if [ "$PRIMARY_COUNT" = "1" ]; then
    echo "Shard3 PRIMARY elected!"
    break
  fi
  
  echo "Waiting for shard3 PRIMARY... ($WAIT_COUNT/$MAX_WAIT)"
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

echo "All replica sets ready. Waiting 10 seconds before adding shards..."
sleep 10

echo "Adding shards to mongos....."
docker exec mongos mongosh --port 27017 --eval '
let retries = 10;
let delay = 5000;

for (let i = 0; i < retries; i++) {
  try {
    print("Attempt " + (i + 1) + " to add shards...");
    
    // Check if sharding is enabled
    let status = sh.status();
    let existingShards = [];
    
    // Safely check for existing shards
    if (status && status.shards && Array.isArray(status.shards)) {
      existingShards = status.shards.map(s => s._id);
    }
    
    print("Current shards: " + JSON.stringify(existingShards));
    
    // Add shard1
    if (!existingShards.includes("shard1ReplSet")) {
      print("Adding shard1...");
      sh.addShard("shard1ReplSet/shard1:27018,shard1-1:27018,shard1-2:27018");
      print("✓ Shard1 added successfully!");
    } else {
      print("✓ Shard1 already exists");
    }
    
    // Add shard2
    if (!existingShards.includes("shard2ReplSet")) {
      print("Adding shard2...");
      sh.addShard("shard2ReplSet/shard2:27019,shard2-1:27019,shard2-2:27019");
      print("✓ Shard2 added successfully!");
    } else {
      print("✓ Shard2 already exists");
    }
    
    // Add shard3
    if (!existingShards.includes("shard3ReplSet")) {
      print("Adding shard3...");
      sh.addShard("shard3ReplSet/shard3:27029,shard3-1:27029,shard3-2:27029");
      print("✓ Shard3 added successfully!");
    } else {
      print("✓ Shard3 already exists");
    }
    
    print("All shards configured successfully!");
    break;
    
  } catch(e) {
    print("❌ Attempt " + (i + 1) + " failed: " + e.message);
    if (i < retries - 1) {
      print("Retrying in 5 seconds...");
      sleep(delay);
    } else {
      print("ERROR: Failed to add shards after " + retries + " attempts");
    }
  }
}
'

echo ""
echo "======================================"
echo "Cluster Status:"
echo "======================================"
docker exec mongos mongosh --port 27017 --eval '
try {
  sh.status();
} catch(e) {
  print("Error getting cluster status: " + e.message);
}
'

echo ""
echo "Script completed!"