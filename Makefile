# ml-training-platform — see BLUEPRINT.md for phases and scope.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

ANSIBLE_DIR := ansible
KUBECONFIG  ?= $(CURDIR)/kubeconfig
export KUBECONFIG
export ANSIBLE_CONFIG := $(CURDIR)/$(ANSIBLE_DIR)/ansible.cfg

.PHONY: help bootstrap cluster argocd verify argocd-ui argocd-password reset lint deps

help: ## List targets
	@grep -E '^[a-zA-Z0-9_%-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  %-18s %s\n", $$1, $$2}'

bootstrap: cluster argocd verify ## Fresh VMs -> K3s cluster with ArgoCD synced

deps: ## Install Ansible collections
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml

cluster: deps ## Harden nodes and install K3s (1 server, 2 agents)
	@test -f $(ANSIBLE_DIR)/inventory/hosts.ini || { echo "Missing $(ANSIBLE_DIR)/inventory/hosts.ini (copy hosts.ini.example)"; exit 1; }
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml

argocd: ## Install ArgoCD and the root app (the only direct kubectl apply)
	./scripts/bootstrap-argocd.sh

verify: ## Check nodes Ready and every ArgoCD app Synced + Healthy
	./scripts/verify-cluster.sh

argocd-ui: ## Port-forward the ArgoCD UI to https://localhost:8080
	kubectl -n argocd port-forward svc/argocd-server 8080:443

argocd-password: ## Print the initial ArgoCD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

reset: ## Uninstall K3s from all nodes (keeps OS hardening)
	cd $(ANSIBLE_DIR) && ansible-playbook reset.yml
	rm -f $(KUBECONFIG)

lint: ## yamllint, ansible-lint, kubeconform
	./scripts/lint.sh

drill-%: ## Failure drills (added with phases 3-5)
	@echo "drill-$* is not implemented yet; see BLUEPRINT.md 'Failure drills'." && exit 1
