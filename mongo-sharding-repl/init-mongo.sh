#!/bin/bash

echo "Inititalize MongoDB config server"
docker compose exec -T mongo-sharding-repl-config mongosh <<EOF
rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [
        { _id: 0, host: "mongo-sharding-repl-config:27017" }
    ]
});
EOF
echo "Initialize MongoDB config server: Wait for 5 seconds"
sleep 5

echo "Initialize shard #1"
docker compose exec -T mongo-sharding-repl-shard1 mongosh <<EOF
rs.initiate({
    _id: "shard1",
    members: [
        { _id: 0, host: "mongo-sharding-repl-shard1:27017" },
        { _id: 1, host: "mongo-sharding-repl-shard1-repl-1:27017" },
        { _id: 2, host: "mongo-sharding-repl-shard1-repl-2:27017" },
        { _id: 3, host: "mongo-sharding-repl-shard1-repl-3:27017" }
    ]
});
EOF
echo "Initialize shard #1: Wait for 5 seconds"
sleep 5

echo "Initialize shard #2"
docker compose exec -T mongo-sharding-repl-shard2 mongosh <<EOF
rs.initiate({
    _id: "shard2",
    members: [
        { _id: 0, host: "mongo-sharding-repl-shard2:27017" },
        { _id: 1, host: "mongo-sharding-repl-shard2-repl-1:27017" },
        { _id: 2, host: "mongo-sharding-repl-shard2-repl-2:27017" },
        { _id: 3, host: "mongo-sharding-repl-shard2-repl-3:27017" }
    ]
});
EOF
echo "Initialize shard #2: Wait for 5 seconds"
sleep 5

echo "Adding shards"
docker compose exec -T mongo-sharding-repl-router mongosh <<EOF
sh.addShard("shard1/mongo-sharding-repl-shard1:27017,mongo-sharding-repl-shard1-repl-1:27017,mongo-sharding-repl-shard1-repl-2:27017,mongo-sharding-repl-shard1-repl-3:27017");
sh.addShard("shard2/mongo-sharding-repl-shard2:27017,mongo-sharding-repl-shard2-repl-1:27017,mongo-sharding-repl-shard2-repl-2:27017,mongo-sharding-repl-shard2-repl-3:27017");
EOF

echo "Create database аnd enable sharding"
docker compose exec -T mongo-sharding-repl-router mongosh <<EOF
use somedb;
sh.enableSharding("somedb");
db.createCollection("helloDoc");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
EOF

echo "Fill databased with test data"
docker compose exec -T mongo-sharding-repl-router mongosh <<EOF
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
EOF

echo "Get shard distribution"
docker compose exec -T mongo-sharding-repl-router mongosh <<EOF
use somedb;
db.helloDoc.getShardDistribution();
EOF
