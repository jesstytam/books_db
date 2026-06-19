# :bookmark: Book tracker (WIP)

<p align="left">
  <a href="/github/actions/workflow/status/:user/:repo/:workflow"><img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/jesstytam/books_db/.github%2Fworkflows%2Fdocker-image.yml" /></a>
</p>


This repository documents the development of a simple book tracking application using FastAPI and PostgreSQL. Here, I (1) built the simple app, (2) containerise them with **Docker**, (3) built a CI/CD with **GitHub Actions**, (4) provisioned Azure infrastructure using **Terraform**, and (5) orchestrated the containers with **Kubernetes**.

## Table of Contents

- [Create application](#create-application)
- [CI/CD pipeline setup](#cicd-pipeline-setup)
- [Deployment](#deployment)
- [Kubernetes](#kubernetes)

## :black_nib: Create application

The overview of the architecture in this section looks something like this when deployed on a local machine:
```
Browser
   |
localhost:8000
   |
FastAPI Container
   |
Docker Network
   |
PostgreSQL Container
```

### Setting up FastAPI

To verify that `FastAPI` was configured correctly, I first created a simple `"hello world"` endpoint and served it locally using `uvicorn`.

Afterwards, I wrote the `Dockerfile` to containerise the app, with instructions to install dependencies.

```
#get docker image
FROM python:3.12-slim

#set working dir
WORKDIR /app

#install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

#copy repo
COPY . .

#run app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

To build the containerised image and launch it there, I ran

```
docker build -t books_db .
docker run -p 8000:8000 books_db
```

### Setting up Postgres DB

To generate the Postgres database, I wrote an SQL script with instructions to create and populate a table of five books, their authors, and book status. 

```
--create table
CREATE TABLE books (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    author VARCHAR(255),
    status VARCHAR(255)
);

--populate table
INSERT INTO books (title, author, status)
VALUES ('For the Emperor', 'Sandy Mitchell', 'read'),
('The Hobbit', 'J. R. R. Tolkien', 'read'),
('The Bell Jar', 'Sylvia Plath', 'read'),
('Dracula', 'Bram Stoker', 'reading'),
('The Master and Margarita', 'Mikhail Bulgakov', 'to be read');
```

Then, I wrote `docker-compose.yml` that defines the instructions to management the deployment of multiple Docker containers involved in this project.

```
services:
  api:

    build: . #builds app image
    ports:
      - "8000:8000" #host_port:container_port
    depends_on:
      - db #start db container before api

  db:

    container_name: postgres
    image: postgres:17

    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password
      POSTGRES_DB: booktracker_db

    ports:
      - "5432:5432" #default postgres port

    volumes:
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql #host_file:container_file
```

And then ran the following to build and run the containers
```
docker compose up
docker compose down -v #removes associated Docker volumes and deletes any persisted database data
```

While the container is still running, in another terminal, I checked that their statuses by running
```
docker ps
```
and 
```
docker exec -it postgres psql -U admin -d booktracker_db
```
to explore or update the database.
![books_table](assets/books_table.png)

### Connecting FastAPI app to Postgres DB

I used `psycopg` to connect the FastAPI application to the PostgreSQL database. The `/books` endpoint executed a SQL query against the database and returned the results as JSON.

During development, whenever the application code or dependencies were updated, I rebuilt and restarted the containers using
```
docker compose down
docker compose up --build
```
to ensure that the application image is using the most up-to-date code and dependencies.

After deployment, I verified that the application was functioning as intended by querying
```
localhost:8000/books
```
![books_json](assets/books_json.png)

## :hammer_and_wrench: CI/CI pipeline setup

GitHub Actions was configured to automatically build and test the application whenever changes were pushed to the repository. The workflow launches the FastAPI and PostgreSQL containers using Docker Compose, waits for the services to initialise, verifies that the /health and /books endpoints return successful responses, and then removes the containers regardless of whether the tests pass or fail.

```
steps:

    - uses: actions/checkout@v4

    - name: Start Docker
      run: docker compose up -d --build #run in detached mode so the workflow can continue to subsequent test steps

    - name: Wait for API to start #allow fastapi and postgresql time to initialise before testing
      run: sleep 10

    - name: Show running containers
      run: docker compose ps

    - name: Check health endpoint status
      run: curl --fail http://localhost:8000/health

    - name: Check books endpoint status
      run: curl --fail http://localhost:8000/books

    - name: Show Docker logs if fail
      if: failure()
      run: docker compose logs

    - name: Shutdown Docker
      if: always()
      run: docker compose down #clean up containers even if a previous step fails
```

## :world_map: Deployment

### Configure Azure deployment with Terraform

Terraform is an Infrastructure as Code (IaC) tool that allows cloud infrastructure to be defined in configuration files, making resources easier to reproduce, review, and update.

I created three Terraform files: `main.tf`, `variables.tf`, and `terraform.tfvars`. The main configuration references an existing Azure Resource Group and creates a new Azure Container Registry.

```
# Configure the Azure provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

#call existing resource
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

#create container registry
resource "azurerm_container_registry" "acr" {
  name = var.container_registry_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  sku = "Basic"
  admin_enabled = false
}
```

I then initialised terraform directories by running
```
terraform init
```
and verified that the application can be deployed on Azure properly. I also made sure to save the plan for reproducibility
```
terraform plan -out=tfplan
```
and confirm that we are ouly creating one resource, as stated in the output `Plan: 1 to add, 0 to change, 0 to destroy`.

Finally, I applied the plan we created as follows
```
terraform apply tfplan
```

I ran the following to check the state and confirm that Terraform is tracking the registry.
```
terraform shorm
terraform state list
```

Whenever the Azure infrastructure configuration changes, I ran `terraform plan` to review the proposed changes before applying them with `terraform apply`.

To minimise cloud costs during development, infrastructure was provisioned through Terraform and could be recreated or removed on demand using `terraform apply` and `terraform destroy`.

### GitHub Actions

Next, I extended the GitHub Actions workflow to authenticate with Azure and push the application image to Azure Container Registry. These steps were executed only during `push` events and were placed after the Docker Compose integration tests to ensure that only validated images were published.
```
    - name: Log in to Azure
      uses: azure/login@v2
      if: github.event_name=='push'
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Log in to ACR
      if: github.event_name=='push'
      run: az acr login --name booksdb

    - name: Build image
      if: github.event_name=='push'
      run: docker build -t booksdb.azurecr.io/d20:latest .

    - name: Push image
      if: github.event_name=='push'
      run: docker push booksdb.azurecr.io/d20:latest
```

On Azure, check containtain register has a new repository

## :package: Kubernetes

create akc resource

```
resource "azurerm_kubernetes_cluster" "aks" {
  name = var.azurerm_kubernetes_cluster
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  #kubernetes setup
  dns_prefix          = "booksdb"
  default_node_pool {
    name       = "default" #larger companies may have frontend-pool, backend-pool, etc.
    node_count = 1 
    vm_size    = "Standard_B2s"
  }
  identity {
    type = "SystemAssigned" #creates AKS Identity for assigning permissions to
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id #kublet_identity will exist after aks is created
  role_definition_name = "AcrPull"
  scope = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
```

run terraform plan -out=tfplan to check that we are creating two resources `Plan: 2 to add, 0 to change, 0 to destroy`.

connect az to local kubernetes

```
$ az aks get-credentials \
  --resource-group portfolio-rg \
  --name booksdb-k8
```

see nodes
```
$ kubectl get nodes
NAME                              STATUS   ROLES    AGE     VERSION
aks-default-30271418-vmss000000   Ready    <none>   9m47s   v1.34.8
```


```
$ kubectl get pods -A
NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
kube-system   azure-cns-2l6b7                                1/1     Running   0          11m
kube-system   azure-ip-masq-agent-4474n                      1/1     Running   0          11m
kube-system   cloud-node-manager-9859c                       1/1     Running   0          11m
kube-system   coredns-779f9587cb-m8pnq                       1/1     Running   0          11m
kube-system   coredns-779f9587cb-sbwqn                       1/1     Running   0          10m
kube-system   coredns-autoscaler-7b4685fdfc-smws2            1/1     Running   0          11m
kube-system   csi-azuredisk-node-rdpv4                       3/3     Running   0          11m
kube-system   csi-azurefile-node-mrf49                       4/4     Running   0          11m
kube-system   konnectivity-agent-7fc4d4987c-fwmsk            1/1     Running   0          11m
kube-system   konnectivity-agent-7fc4d4987c-h2z42            1/1     Running   0          10m
kube-system   konnectivity-agent-autoscaler-95f4794f-9cb6g   1/1     Running   0          11m
kube-system   kube-proxy-l5x75                               1/1     Running   0          11m
kube-system   metrics-server-5f5fbb69b-p2bg7                 2/2     Running   0          10m
kube-system   metrics-server-5f5fbb69b-xkbs5                 2/2     Running   0          10m
```


```
$ kubectl get namespaces
NAME              STATUS   AGE
default           Active   13m
kube-node-lease   Active   13m
kube-public       Active   13m
kube-system       Active   13m
```