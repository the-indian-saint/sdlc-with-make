#chang the docker repository name and project name and authenticate with your docker repository
#The data provided in .catalog.yml can be used to pass tags to the underlying infrastructure.
REPOSITORY := rohanmatkar
PROJECT_NAME := $(shell python -c "import yaml; data = yaml.safe_load(open('.catalog.yml')); print(data['component']['name'])")
CATALOG_VERSION := $(shell python -c "import yaml; data = yaml.safe_load(open('.catalog.yml')); print(data['version'])")
AWS_REGION := us-east-2
ARGO_CHART_VERSION := 5.5.18
INGRESS_CHART_VERSION := 4.5.2


TERRAFORM_DIR := $(shell pwd)/terraform-config
HELM_DIR := $(shell pwd)/helm-config
APP_DIR := $(shell pwd)/application

# Determine the VERSION dynamically based on git branch or repository status
ifeq ($(shell git rev-parse --is-inside-work-tree 2>/dev/null),true)
	BRANCH := $(shell git symbolic-ref --short HEAD)
	ifeq ($(BRANCH),master)
		VERSION := $(shell git rev-parse --short HEAD)
	else ifeq ($(BRANCH),main)
		VERSION := $(shell git rev-parse --short HEAD)
	else
		VERSION := $(CATALOG_VERSION)
	endif
else
	VERSION := "latest"
endif

CONTAINER_NAME := $(REPOSITORY)/$(PROJECT_NAME):$(VERSION)
KUBE_CTX := prod


####################Local Build Targets####################

.PHONY: build
build:
	@echo "Building $(CONTAINER_NAME)"
	docker build . -t $(CONTAINER_NAME) --file ./application/Dockerfile

#chekout localhost:8080 after running this command
.PHONY: run
run: build
	@echo "Running $(CONTAINER_NAME)"
	docker run -p 8080:8080 $(CONTAINER_NAME)

#push the docker image to the repository
.PHONY: push
push:
	@echo "Pushing $(CONTAINER_NAME)"
	docker push $(CONTAINER_NAME)


#############K8s Targets#############


.PHONY: deploy-k8s
deploy-k8s:
	-kubectl create namespace $(PROJECT_NAME)
	helm upgrade --install --kube-context=$(KUBE_CTX) $(PROJECT_NAME) $(shell pwd)/helm-config/$(PROJECT_NAME) --namespace $(PROJECT_NAME)


####################Minikube Targets####################


.PHONY: minikube-start
minikube-start:
	@echo "Starting minikube"
	minikube start --driver=docker
	@echo "Enabling ingress"
	minikube addons enable ingress

.PHONY: minikube-stop
minikube-stop:
	@echo "Stopping minikube"
	minikube stop

.PHONY: deploy-minikube
deploy-minikube:
	-kubectl create namespace $(PROJECT_NAME)
	helm upgrade --install --kube-context=minikube $(PROJECT_NAME) $(shell pwd)/helm-config/$(PROJECT_NAME) --namespace $(PROJECT_NAME)

.PHONY: get-url
get-url:
	@echo "Getting URL for $(PROJECT_NAME)"
	minikube service $(PROJECT_NAME) --url --namespace $(PROJECT_NAME)

.PHONY: tunnel
tunnel:
	@echo "Tunneling to $(PROJECT_NAME)"
	minikube tunnel

####################Terraform Targets####################

.PHONY: terraform-init
terraform-init:
	@echo "Initializing Terraform"
	cd $(TERRAFORM_DIR) && terraform init

.PHONY: terraform-validate
terraform-validate: terraform-init
	@echo "Validating Terraform"
	cd $(TERRAFORM_DIR) && terraform validate

.PHONY: terraform-fmt
terraform-fmt: terraform-validate
	@echo "Formatting Terraform"
	cd $(TERRAFORM_DIR) && terraform fmt

.PHONY: terraform-plan
terraform-plan: terraform-fmt
	@echo "Planning Terraform"
	cd $(TERRAFORM_DIR) && terraform plan -var "cluster-name=$(PROJECT_NAME)-cluster" -var "vpc-name=$(PROJECT_NAME)-vpc" -var "region=$(AWS_REGION)"

.PHONY: terraform-apply
terraform-apply: terraform-plan
	@echo "Applying Terraform"
	cd $(TERRAFORM_DIR) && terraform apply --auto-approve -var "cluster-name=$(PROJECT_NAME)-cluster" -var "vpc-name=$(PROJECT_NAME)-vpc" -var "region=$(AWS_REGION)"
	cd ..

.PHONY: terraform-destroy
terraform-destroy:
	@echo "Destroying Terraform"
	cd $(TERRAFORM_DIR) && terraform destroy --auto-approve
	cd ..

#This command takes a while to run. Please be patient.
.PHONY: create-cluster
create-cluster: terraform-apply


############PROD Targets############

#this command will get the context and set as default
.PHONY: get-context
get-context:
	@echo "Getting context"
	aws eks --region $(AWS_REGION) update-kubeconfig --name $(PROJECT_NAME)-cluster --alias $(KUBE_CTX)

.PHONY: deploy-prod
deploy-prod: get-context
deploy-prod:
	-kubectl create namespace $(PROJECT_NAME)
	helm upgrade --install --kube-context=$(KUBE_CTX) $(PROJECT_NAME) $(shell pwd)/helm-config/$(PROJECT_NAME) \
	-f $(shell pwd)/helm-config/$(PROJECT_NAME)/values-$(KUBE_CTX).yaml --namespace $(PROJECT_NAME)

#####################Ingress Targets#####################


#ingress configuration can be omiited.
.PHONY: ingress-dump-default-values
ingress-dump-default-values:
	-mkdir values/v$(CHART_VERSION)
	helm show values ingress-nginx/ingress-nginx --version=$(INGRESS_CHART_VERSION) > $(HELM_DIR)/ingress/values/$(INGRESS_CHART_VERSION)_default.yaml

.PHONE: deploy-ingress
deploy-ingress: ingress-dump-default-values
	helm --kube-context $(KUBE_CTX) list --all --all-namespaces
	helm search repo ingress-nginx
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	kubectl --context=$(KUBE_CTX) create namespace ingress-nginx
	$(shell mkdir -p $(HELM_DIR)/argocd/values/$(INGRESS_CHART_VERSION)/)
	$(shell cp $(HELM_DIR)/ingress/values/$(INGRESS_CHART_VERSION)_default.yaml $(HELM_DIR)/ingress/values/$(INGRESS_CHART_VERSION)/$(KUBE_CTX).yaml)
	helm upgrade --install --kube-context=$(KUBE_CTX) --namespace=ingress-nginx ingress-nginx ingress-nginx/ingress-nginx --version=$(INGRESS_CHART_VERSION) \
	-f $(HELM_DIR)/ingress/values//$(INGRESS_CHART_VERSION)/$(KUBE_CTX).yaml
	kubectl --context=$(KUBE_CTX) --namespace=ingress-nginx get all


#####################ArgoCD Targets#####################


.PHONY: argocd-init
argocd-init: get-context
	@echo "Installing ArgoCD"
	helm --kube-context $(KUBE_CTX) list --all --all-namespaces
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update

.PHONY: argocd-dump-default-values
argocd-dump-default-values: argocd-init
	@echo "Dumping default values"
	helm show values argo/argo-cd --version=$(ARGO_CHART_VERSION) > $(HELM_DIR)/argocd/values/$(ARGO_CHART_VERSION)_default.yaml

.PHONY: argocd-deploy
argocd-deploy: argocd-dump-default-values
argocd-deploy: 
	-kubectl --context=$(KUBE_CTX) create namespace argocd
	$(shell mkdir -p $(HELM_DIR)/argocd/values/$(ARGO_CHART_VERSION)/)
	$(shell cp $(HELM_DIR)/argocd/values/$(ARGO_CHART_VERSION)_default.yaml $(HELM_DIR)/argocd/values/$(ARGO_CHART_VERSION)/$(KUBE_CTX).yaml)
	helm upgrade --install --kube-context=$(KUBE_CTX) argocd argo/argo-cd --namespace argocd --version=$(ARGO_CHART_VERSION) \
	-f $(HELM_DIR)/argocd/values/$(ARGO_CHART_VERSION)/$(KUBE_CTX).yaml
	
.PHONY: get-argocd-password
get-argocd-password:
	@echo "Getting ArgoCD password"
	kubectl --context=$(KUBE_CTX) -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
