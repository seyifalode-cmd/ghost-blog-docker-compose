<!-- Install docker on ec2 machine -->

sudo yum install docker -y && sudo systemctl start docker

<!-- Install docker compose -->

sudo yum install -y curl && \
VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4) && \
sudo curl -L "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose && \
sudo chmod +x /usr/bin/docker-compose && \
docker-compose --version

<!-- Run docker compose -->

docker-compose up -d
