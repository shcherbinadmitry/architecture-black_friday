#!/bin/bash

echo "Inititalize MongoDB config server"
docker compose exec -T mongo-sharding-config mongosh <<EOF
rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
        { _id: 0, host: "mongo-sharding-config:27017" }
    ]
});
EOF
echo "Initialize MongoDB config server: Wait for 5 seconds"
sleep 5

echo "Initialize shard #1"
docker compose exec -T mongo-sharding-shard1 mongosh <<EOF
rs.initiate({
    _id: "shard1",
    members: [
        { _id: 0, host: "mongo-sharding-shard1:27017" }
    ]
});
EOF
echo "Initialize shard #1: Wait for 5 seconds"
sleep 5

echo "Initialize shard #2"
docker compose exec -T mongo-sharding-shard2 mongosh <<EOF
rs.initiate({
    _id: "shard2",
    members: [
        { _id: 0, host: "mongo-sharding-shard2:27017" }
    ]
});
EOF
echo "Initialize shard #2: Wait for 5 seconds"
sleep 5

echo "Adding shards"
docker compose exec -T mongo-sharding-router mongosh <<EOF
sh.addShard("shard1/mongo-sharding-shard1:27017");
sh.addShard("shard2/mongo-sharding-shard2:27017");
EOF

echo "Create database аnd enable sharding"
docker compose exec -T mongo-sharding-router mongosh <<EOF
use somedb;
sh.enableSharding("somedb");
db.createCollection("helloDoc");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
EOF

echo "Fill databased with test data"
docker compose exec -T mongo-sharding-router mongosh <<EOF
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
EOF

echo "Get shard distribution"
docker compose exec -T mongo-sharding-router mongosh <<EOF
use somedb;
db.helloDoc.getShardDistribution();
EOF
