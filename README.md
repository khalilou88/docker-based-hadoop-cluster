# Docker-based Hadoop Cluster

A modular Docker-based Hadoop ecosystem where you can activate only the services you need.

## Quick Start

1. **Make the management script executable:**
   ```bash
   chmod +x cluster.sh
   ```

2. **Start basic Hadoop:**
   ```bash
   ./cluster.sh start hadoop
   ```

3. **Add Hive when you need it:**
   ```bash
   ./cluster.sh start hive
   ```

4. **Check what's running:**
   ```bash
   ./cluster.sh status
   ```

## Available Services

| Service | Description | Key Ports |
|---------|-------------|-----------|
| **hadoop** | Core Hadoop (HDFS, YARN, MapReduce) | 9870, 8088, 8188 |
| **hive** | Hive Server with PostgreSQL metastore | 10000, 9083 |
| **spark** | Spark Master and Workers | 8080, 7077, 8081-8082 |
| **hbase** | HBase with Zookeeper | 16010, 16030, 2181   |
| **kafka** | Kafka with Management UI | 9092, 9093, 2182     |
| **dev-tools** | Jupyter, Airflow, Portainer | 8888, 8083, 9443     |

## Management Commands

### Start Services
   ```bash
   ./cluster.sh start hadoop hive        # Start specific services
   ```

   ```bash
   ./cluster.sh start all                # Start everything
   ```

### Stop Services
   ```bash
   ./cluster.sh stop spark               # Stop specific service
   ```

   ```bash
   ./cluster.sh stop all                 # Stop everything
   ```

### Other Commands
```bash
./cluster.sh status                   # Show status
```

```bash
./cluster.sh restart hive             # Restart service
```

```bash
./cluster.sh logs hadoop              # Show logs
```

```bash
./cluster.sh list                     # List available services
```

```bash
./cluster.sh clean                    # Stop all and remove volumes
```

## Common Usage Patterns

### For Data Engineering
```bash
./cluster.sh start hadoop hive spark
```

### For Real-time Processing
```bash
./cluster.sh start hadoop kafka spark
```

### For NoSQL Development
```bash
./cluster.sh start hadoop hbase
```

### For Complete Development Environment
```bash
./cluster.sh start all
```

## Service Dependencies

- **hive**, **spark**, **hbase** automatically start **hadoop** if not running
- **kafka** runs independently (has its own Zookeeper)
- **dev-tools** can connect to any running services

## Web UIs

| Service | URL | Description |
|---------|-----|-------------|
| Hadoop NameNode | http://localhost:9870 | HDFS status |
| YARN ResourceManager | http://localhost:8088 | Job tracking |
| Spark Master | http://localhost:8080 | Spark cluster |
| HBase Master | http://localhost:16010 | HBase status |
| Kafka Manager | http://localhost:9093  | Kafka topics |
| Jupyter | http://localhost:8888  | Notebooks |
| Airflow | http://localhost:8083  | Workflows (admin/admin) |
| Portainer | http://localhost:9443  | Container


## Common Commands:

### Connect to Hive:
```bash
docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000
```

### Access Spark Shell:
```bash
docker exec -it spark-master spark-shell
```


### HDFS Commands:
```bash
docker exec -it namenode hdfs dfs -ls /
```

```bash
docker exec -it namenode hdfs dfs -mkdir /user/data
```


### HBase Shell:
```bash
docker exec -it hbase-master hbase shell
```
