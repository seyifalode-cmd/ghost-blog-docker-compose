**Ghost Blog on AWS — Containerized CMS Deployment with Terraform and Docker Compose**

Deploy a production-ready Ghost blogging platform on AWS EC2 using Terraform for infrastructure provisioning and Docker Compose for container orchestration, with a persistent MySQL backend.

---

## Project at a Glance

| Attribute      | Detail                                                              |
|----------------|---------------------------------------------------------------------|
| Tools Used     | Terraform, Docker, Docker Compose, AWS EC2, AWS VPC                 |
| Platform       | Amazon Web Services (AWS) — us-east-1                               |
| Languages      | HCL (Terraform), YAML (Docker Compose)                              |
| What It Does   | Provisions a networked AWS environment and deploys Ghost CMS with a MySQL backend inside Docker containers on a single EC2 instance |

---

## The Problem This Project Solves

Deploying a content management system like Ghost typically involves manual server configuration, dependency management, and database setup — a process that is time-consuming, error-prone, and difficult to reproduce. Teams that rely on manual deployments cannot easily recreate environments or recover from failures without significant effort.

This project solves that problem by treating infrastructure and application deployment as code. Terraform provisions the VPC, subnets, routing, security groups, and EC2 instance in a repeatable, declarative manner. Docker Compose then orchestrates the Ghost application and MySQL database as isolated containers with persistent volumes, removing the need to install or configure either service directly on the host OS.

The result is a fully automated deployment pipeline: a single `terraform apply` stands up all network and compute infrastructure, and a single `docker-compose up -d` launches the entire application stack. This approach is consistent across environments and can be torn down and rebuilt at any time with zero configuration drift.

---

## Architecture

```
Developer Workstation
        |
        | terraform apply
        v
+-----------------------------+
|        AWS (us-east-1)      |
|                             |
|  +------------------------+ |
|  |   Terraform-VPC        | |
|  |   CIDR: 10.0.0.0/16    | |
|  |                        | |
|  |  +------------------+  | |
|  |  | Public Subnet    |  | |
|  |  | 10.0.1.0/24      |  | |
|  |  |                  |  | |
|  |  | +------------+   |  | |
|  |  | | EC2 t3.micro|  |  | |
|  |  | | (Amazon     |  |  | |
|  |  | |  Linux 2)   |  |  | |
|  |  | |             |  |  | |
|  |  | | Docker      |  |  | |
|  |  | | Compose     |  |  | |
|  |  | |  ghost:3    |  |  | |
|  |  | |   :80       |  |  | |
|  |  | |  mysql:5.7  |  |  | |
|  |  | +------------+  |  | |
|  |  +------------------+  | |
|  |         |               | |
|  |  Internet Gateway       | |
|  +------------------------+ |
+-----------------------------+
        |
  TCP/80 open to 0.0.0.0/0
  TCP/22 open to 0.0.0.0/0
```

**Infrastructure Layer (Terraform)**

Terraform provisions a custom VPC with DNS support enabled, a public subnet in a single availability zone, an internet gateway, and a route table that directs all outbound traffic through the gateway. A security group permits inbound HTTP (port 80) and SSH (port 22). The EC2 instance is a t3.micro running Amazon Linux 2, resolved via SSM Parameter Store for the latest AMI ID.

**Application Layer (Docker Compose)**

The `docker-compose.yml` defines two services. The `ghost` service runs the Ghost 3 Alpine image, exposing port 80 externally and connecting to the `mysql` service internally by container name. The `mysql` service runs MySQL 5.7. Both services use named Docker volumes (`ghost-volume`, `mysql-volume`) to persist data across container restarts.

---

## Repository Structure

```
ghost-blog-docker-compose/
├── docker/
│   └── docker-compose.yml          # Ghost + MySQL service definitions
├── modules/
│   ├── compute/
│   │   ├── main.tf                 # EC2 instance, key pair configuration
│   │   ├── outputs.tf              # Instance outputs
│   │   └── variables.tf            # Compute module variables
│   └── vpc/
│       ├── main.tf                 # VPC, subnet, IGW, route table, security group
│       ├── outputs.tf              # VPC outputs
│       └── variables.tf            # VPC module variables
├── main.tf                         # Root module — wires vpc and compute modules
├── variables.tf                    # Root variables (region)
├── outputs.tf                      # Root outputs
└── notes.md                        # Manual setup commands reference
```

---

## How It Works

1. Terraform reads the root `main.tf`, which calls the `vpc` module to build the network layer and the `compute` module to launch the EC2 instance.
2. The compute module uses the AWS SSM Parameter Store to dynamically resolve the latest Amazon Linux 2 AMI, ensuring the instance is always built on a current image.
3. Once the EC2 instance is running, Docker and Docker Compose are installed manually (or automated via user-data in a production variant).
4. `docker-compose up -d` is run on the instance, which pulls the `ghost:3-alpine` and `mysql:5.7` images, creates the named volumes, and starts both containers.
5. Ghost connects to MySQL using the `database__connection__host: mysql` environment variable, resolving the hostname via Docker's internal DNS.
6. The blog is then accessible on the EC2 public IP over port 80.

---

## Walkthrough

**Step 1 — Provision AWS infrastructure with Terraform**

```bash
terraform init
terraform plan
terraform apply
```

**Step 2 — SSH into the provisioned EC2 instance**

```bash
ssh -i ~/.ssh/id_ed25519 ec2-user@<EC2_PUBLIC_IP>
```

**Step 3 — Install Docker on the EC2 instance**

```bash
sudo yum install docker -y && sudo systemctl start docker
```

**Step 4 — Install Docker Compose**

```bash
sudo yum install -y curl
VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
docker-compose --version
```

**Step 5 — Launch the Ghost + MySQL stack**

```bash
cd /path/to/docker/
docker-compose up -d
```

**Step 6 — Verify running containers**

```bash
docker ps
```

Ghost is now accessible at `http://<EC2_PUBLIC_IP>/`.

---

## How to Reproduce

```bash
# Clone the repository
git clone https://github.com/seyifalode-cmd/ghost-blog-docker-compose.git
cd ghost-blog-docker-compose

# Export AWS credentials
export AWS_ACCESS_KEY_ID=<your-key-id>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>

# Provision infrastructure
terraform init
terraform apply -auto-approve

# SSH in and set up Docker
ssh -i ~/.ssh/id_ed25519 ec2-user@$(terraform output -raw instance_public_ip)
sudo yum install docker -y && sudo systemctl start docker

# Start the application stack
docker-compose -f docker/docker-compose.yml up -d

# Destroy when done
terraform destroy -auto-approve
```

**Prerequisites**

- Terraform >= 0.15.5
- AWS account with credentials configured
- SSH key pair at `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`
- AWS provider version ~> 3.44.0

---

*Oluwaseyi Michael Falode · Cybersecurity & Cloud Security Engineer · Toronto, ON*
