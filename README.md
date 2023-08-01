# A complete CI/CD lifecycle for a GOlang application using Make

This repository contains a Makefile to automate various tasks related to building, deploying, and managing an application's infrastructure using Docker, Kubernetes, Helm, aws-cli and Terraform. The Makefile provides a simple and efficient way to streamline your development workflow and ensure consistency across different environments.
The Makefile abstracts away the complexity of managing infrastructure components such as Docker containers, Kubernetes deployments, and Terraform resources. The targets in the Makefile are designed to be intuitive and self-explanatory, allowing developers to interact with the infrastructure without delving into the intricacies of the underlying tools.
The Makefile supports deploying to both local Minikube clusters and production Kubernetes clusters with ease. By leveraging the Helm chart for Kubernetes deployments, the Makefile ensures consistency and reliability in deploying the application to different environments. Additionally, the Terraform targets facilitate the provisioning and management of cloud resources, enabling a smooth transition from development to production environments.

## Prerequisites

Before using this Makefile to automate your application's infrastructure, ensure that the following prerequisites are met on your local development environment:

1. **Helm:** Helm is required for deploying Kubernetes applications. Make sure to have Helm installed and configured to interact with your Kubernetes clusters.

2. **AWS CLI:** The AWS CLI is necessary for fetching EKS context. Download aws-cli and setup a named profile for terraform(make sure approriate permissions are given to the account.)

3. **Python:** Python is used in the Makefile to extract information from the `catalog.yaml` file. Make sure Python is installed on your system. This information can be used to set tags for AWS resources.

4. **Terraform:** Terraform is required for provisioning cloud resources and infrastructure. Ensure Terraform is installed and accessible from the command line.

5. **kubectl:** Kubectl is necessary for interacting with Kubernetes clusters. Ensure kubectl is installed and configured to work with your Kubernetes clusters.

6. **Minikube(Optional):** Install Minikube for local testing.

## Usage

### Variables

1. **REPOSITORY -** Name of the docker registry to push the docker image.
2. **PROJECT_NAME -** The name of the project. This is fetched from the `.catalog.yml` file.
3. **CATALOG_VERSION -** Version of the catalog, fetched from the `.catalog.yml` file.
4. **TERRAFORM_REGION -** AWS region to deploy VPC and EKS cluster.
5. **VERSION -** Docker image version to push. If makefile is present inside a GIT repository and the brach is `main` or `master`, the value will be fetched from the latest commit hash. For every other branch, the value is set to `CATALOG_VERSION`. The value will be set to `latest` if no git data is found.
6. **KUBE_CTX -** Name of the K8s context.
7. **ARGO_CHART_VERSION -** Version of the ArgoCD chart.
8. **INGRESS_CHART_VERSION -** Vesrion of the ingress controller chart.

### Local Build Targets

Run the application:

```bash
make run
```

Push docker image to repository:

```bash
make push
```

### Minikube Targets

Start and enable ingress:

```bash
make enable-ingress
```

Deploy to minikube:

```bash
make deploy-minikube
```

Get minikube svc URL:

```bash
make get-url
```

### Terraform Targets

Modules used:

1. **EKS -** `terraform-aws-modules/eks/aws`
2. **VPC -** `terraform-aws-modules/vpc/aws`

These public modules are used to adhere to the time limit of challenge. In an actual scenario, self-hosted modules should be used.

Following Makefile target creates a vpc with public and private subnets and creates an EKS cluster aws managed node groups.

```bash
make create-cluster
```

To delete created resources:

```bash
make terraform-destroy
```

### Production Targets

Deploy to EKS cluster

```bash
make deploy-prod
```

### ArgoCD Targets for CI/CD

This Makefile can be deployed to any CI and easliy configured to test and build the application. Simply add more targets in `local build targets` to develop, format, test and build the code and use `make push` target to push the image to the repository.
After the image is pushed to the repository, ArgoCD can be used to deploy to the cluster using the GITOPS principals by creating a argo application file.
A very basic setup and installation of ArgoCD can be done using these ArgoCD targets. Ideally, there should be a seperate repository for ArgoCD application configuration to deploy using helm in multiple ArgoCD projects(Project can be used to seperate environments). ArgoCD can then be used for rollback.
