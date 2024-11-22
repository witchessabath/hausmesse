# Bash Skript zum Migrieren der Docker Container

#!/bin/bash

# Variables
LOCAL_HOST="192.168.0.10"
REMOTE_HOST="cluster1@192.168.0.11"
LOCAL_DOCKER_COMPOSE_PATH_SERVER="/home/cluster2/Sync/nginx"
LOCAL_DOCKER_COMPOSE_PATH_MONITORING="/home/cluster2/Sync/monitoring"
REMOTE_DOCKER_COMPOSE_PATH_SERVER="/home/cluster1/Sync/nginx"
REMOTE_DOCKER_COMPOSE_PATH_MONITORING="/home/cluster1/Sync/monitoring"
DOCKER_COMPOSE_COMMAND="up -d"

# Function to check the voltage
check_voltage() {
    local voltage_file="voltage.txt"
    local voltage

    # Read the last line of the voltage file
    if [ -f "$voltage_file" ]; then
        voltage=$(tail -n 1 "$voltage_file")
        echo "Read voltage: '$voltage'"  # Debugging information
    else
        echo "Voltage file not found!"
        return 1
    fi

    # Return the voltage value
    echo "$voltage"
}

# Function to stop local Docker Compose services
stop_local_containers() {
    echo "Stopping local Docker containers..."
    docker compose -f "$LOCAL_DOCKER_COMPOSE_PATH_SERVER/docker-compose.yml" down
    docker compose -f "$LOCAL_DOCKER_COMPOSE_PATH_MONITORING/docker-compose.yml" down
}


# Function to start local Docker Compose services
start_local_containers() {
    echo "Starting local Docker containers..."
    docker compose -f "$LOCAL_DOCKER_COMPOSE_PATH_SERVER/docker-compose.yml" $DOCKER_COMPOSE_COMMAND
    docker compose -f "$LOCAL_DOCKER_COMPOSE_PATH_MONITORING/docker-compose.yml" $DOCKER_COMPOSE_COMMAND
}

# Start the ssh-agent and add the SSH key
eval "$(ssh-agent -s)"
ssh-add /home/cluster2/.ssh/manager11

# Function to stop remote Docker Compose services
stop_remote_containers() {
    echo "Stopping remote Docker containers..."
    ssh -T -i /home/cluster2/.ssh/manager11 -o StrictHostKeyChecking=no $REMOTE_HOST << EOF
        docker compose -f $REMOTE_DOCKER_COMPOSE_PATH_SERVER/docker-compose.yml down
        docker compose -f $REMOTE_DOCKER_COMPOSE_PATH_MONITORING/docker-compose.yml down
EOF
}

# Function to start remote Docker Compose services
start_remote_containers() {
    echo "Starting remote Docker containers..."
    ssh -T -i /home/cluster2/.ssh/manager11 -o StrictHostKeyChecking=no $REMOTE_HOST << EOF
        docker compose -f $REMOTE_DOCKER_COMPOSE_PATH_SERVER/docker-compose.yml $DOCKER_COMPOSE_COMMAND
        docker compose -f $REMOTE_DOCKER_COMPOSE_PATH_MONITORING/docker-compose.yml $DOCKER_COMPOSE_COMMAND
EOF
}

# Main loop
while true; do
    voltage=$(check_voltage)
    if [ $? -ne 0 ]; then
        echo "Error reading voltage. Retrying..."
        sleep 60
        continue
    fi

    if (( $(echo "$voltage < 20.0" | bc -l) )); then
        echo "Voltage is under 20V: $voltage"
        stop_remote_containers
        start_local_containers
    else
        echo "Voltage is over 20V: $voltage"
        stop_local_containers
        start_remote_containers
    fi

    sleep 10  # Sleep for 10 seconds before running the checks again
done
