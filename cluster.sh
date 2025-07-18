#!/bin/bash

# Hadoop Cluster Manager Script
# Usage: ./cluster.sh [start|stop|status|restart] [service1] [service2] ...

AVAILABLE_SERVICES=(
    "hadoop"      # Core Hadoop services (HDFS, YARN, MapReduce)
    "hive"        # Hive with PostgreSQL metastore
    "spark"       # Spark master and workers
    "hbase"       # HBase with Zookeeper
    "kafka"       # Kafka with Zookeeper and Manager
    "dev-tools"   # Jupyter, Airflow, Portainer
)

# Service configurations
declare -A SERVICE_FILES=(
    ["hadoop"]="docker-compose.yml"
    ["hive"]="docker-compose.hive.yml"
    ["spark"]="docker-compose.spark.yml"
    ["hbase"]="docker-compose.hbase.yml"
    ["kafka"]="docker-compose.kafka.yml"
    ["dev-tools"]="docker-compose.dev-tools.yml"
)

declare -A SERVICE_DESCRIPTIONS=(
    ["hadoop"]="Core Hadoop services (HDFS, YARN, MapReduce, History Server)"
    ["hive"]="Hive Server with PostgreSQL metastore"
    ["spark"]="Spark Master and Workers"
    ["hbase"]="HBase with Zookeeper"
    ["kafka"]="Kafka with Zookeeper and Management UI"
    ["dev-tools"]="Development tools (Jupyter, Airflow, Portainer)"
)

declare -A SERVICE_PORTS=(
    ["hadoop"]="9870 (NameNode), 8088 (YARN), 8188 (History)"
    ["hive"]="10000 (HiveServer2), 9083 (Metastore)"
    ["spark"]="8080 (Master UI), 7077 (Master), 8081-8082 (Workers)"
    ["hbase"]="16010 (Master), 16030 (RegionServer), 2181 (Zookeeper)"
    ["kafka"]="9092 (Kafka), 9000 (Manager), 2182 (Zookeeper)"
    ["dev-tools"]="8888 (Jupyter), 8083 (Airflow), 9443 (Portainer)"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_usage() {
    echo "Usage: $0 [COMMAND] [SERVICES...]"
    echo ""
    echo "Commands:"
    echo "  start     Start specified services"
    echo "  stop      Stop specified services"
    echo "  restart   Restart specified services"
    echo "  status    Show status of services"
    echo "  list      List available services"
    echo "  logs      Show logs for specified services"
    echo "  clean     Stop all services and remove volumes"
    echo ""
    echo "Available services:"
    for service in "${AVAILABLE_SERVICES[@]}"; do
        echo "  $service - ${SERVICE_DESCRIPTIONS[$service]}"
    done
    echo ""
    echo "Examples:"
    echo "  $0 start hadoop hive        # Start Hadoop and Hive"
    echo "  $0 stop spark               # Stop Spark"
    echo "  $0 status                   # Show status of all services"
    echo "  $0 start all                # Start all services"
}

function setup_directories() {
    echo "Setting up directories..."
    mkdir -p notebooks dags logs plugins data
    chmod 755 notebooks dags logs plugins data
}

function create_network() {
    if ! docker network ls | grep -q hadoop-network; then
        echo "Creating hadoop-network..."
        docker network create hadoop-network
    fi
}

function wait_for_service() {
    local service=$1
    local max_wait=60
    local count=0

    echo "Waiting for $service to be ready..."
    while [ $count -lt $max_wait ]; do
        if docker compose -f "${SERVICE_FILES[$service]}" ps | grep -q "Up"; then
            echo "$service is ready!"
            return 0
        fi
        sleep 2
        count=$((count + 2))
    done
    echo "Warning: $service may not be fully ready"
    return 1
}

function start_service() {
    local service=$1

    if [[ ! " ${AVAILABLE_SERVICES[@]} " =~ " ${service} " ]]; then
        echo -e "${RED}Error: Unknown service '$service'${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting $service...${NC}"

    # Special handling for services that depend on others
    case $service in
        "hive")
            if ! docker compose -f docker-compose.yml ps | grep -q "Up"; then
                echo "Hadoop must be running before starting Hive. Starting Hadoop first..."
                start_service "hadoop"
            fi
            ;;
        "spark")
            if ! docker compose -f docker-compose.yml ps | grep -q "Up"; then
                echo "Hadoop should be running for Spark integration. Starting Hadoop first..."
                start_service "hadoop"
            fi
            ;;
        "hbase")
            if ! docker compose -f docker-compose.yml ps | grep -q "Up"; then
                echo "Hadoop must be running before starting HBase. Starting Hadoop first..."
                start_service "hadoop"
            fi
            ;;
    esac

    docker compose -f "${SERVICE_FILES[$service]}" up -d

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service started successfully${NC}"
        echo -e "${YELLOW}Ports: ${SERVICE_PORTS[$service]}${NC}"

        # Add service-specific post-start info
        case $service in
            "hive")
                echo "Connect to Hive: docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000"
                ;;
            "dev-tools")
                echo "Jupyter token: docker exec jupyter jupyter server list"
                echo "Airflow login: admin/admin"
                ;;
        esac
    else
        echo -e "${RED}✗ Failed to start $service${NC}"
        return 1
    fi
}

function stop_service() {
    local service=$1

    if [[ ! " ${AVAILABLE_SERVICES[@]} " =~ " ${service} " ]]; then
        echo -e "${RED}Error: Unknown service '$service'${NC}"
        return 1
    fi

    echo -e "${BLUE}Stopping $service...${NC}"
    docker compose -f "${SERVICE_FILES[$service]}" down

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service stopped successfully${NC}"
    else
        echo -e "${RED}✗ Failed to stop $service${NC}"
        return 1
    fi
}

function show_status() {
    echo -e "${BLUE}Service Status:${NC}"
    echo "================"

    for service in "${AVAILABLE_SERVICES[@]}"; do
        echo -e "\n${YELLOW}$service:${NC}"
        if docker compose -f "${SERVICE_FILES[$service]}" ps 2>/dev/null | grep -q "Up"; then
            echo -e "${GREEN}  ✓ Running${NC}"
            docker compose -f "${SERVICE_FILES[$service]}" ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
        else
            echo -e "${RED}  ✗ Stopped${NC}"
        fi
    done
}

function show_logs() {
    local service=$1

    if [[ ! " ${AVAILABLE_SERVICES[@]} " =~ " ${service} " ]]; then
        echo -e "${RED}Error: Unknown service '$service'${NC}"
        return 1
    fi

    docker compose -f "${SERVICE_FILES[$service]}" logs -f
}

function clean_all() {
    echo -e "${YELLOW}Stopping all services and removing volumes...${NC}"

    for service in "${AVAILABLE_SERVICES[@]}"; do
        docker compose -f "${SERVICE_FILES[$service]}" down -v
    done

    echo "Removing network..."
    docker network rm hadoop-network 2>/dev/null || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main script logic
case "$1" in
    "start")
        setup_directories
        create_network

        if [ "$2" = "all" ]; then
            for service in "${AVAILABLE_SERVICES[@]}"; do
                start_service "$service"
            done
        else
            for service in "${@:2}"; do
                start_service "$service"
            done
        fi
        ;;

    "stop")
        if [ "$2" = "all" ]; then
            for service in "${AVAILABLE_SERVICES[@]}"; do
                stop_service "$service"
            done
        else
            for service in "${@:2}"; do
                stop_service "$service"
            done
        fi
        ;;

    "restart")
        for service in "${@:2}"; do
            stop_service "$service"
            start_service "$service"
        done
        ;;

    "status")
        show_status
        ;;

    "list")
        echo "Available services:"
        for service in "${AVAILABLE_SERVICES[@]}"; do
            echo "  $service - ${SERVICE_DESCRIPTIONS[$service]}"
            echo "    Ports: ${SERVICE_PORTS[$service]}"
        done
        ;;

    "logs")
        if [ -z "$2" ]; then
            echo "Please specify a service to show logs for"
            exit 1
        fi
        show_logs "$2"
        ;;

    "clean")
        clean_all
        ;;

    *)
        print_usage
        exit 1
        ;;
esac