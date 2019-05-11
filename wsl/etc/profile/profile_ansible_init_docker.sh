sudo -S cgroupfs-mount
sudo usermod -aG docker $USER
sudo service docker start
# using windows docker-compose
export DOCKER_HOST=tcp://localhost:2375