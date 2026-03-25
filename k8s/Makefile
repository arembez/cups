.PHONY: help install clean update logs shell status

-include .env
export

NAMESPACE ?= cups
APP_NAME ?= cups

GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[0;33m
NC = \033[0m

help:
	@echo "Available commands:"
	@echo "  make install   - Full installation"
	@echo "  make update    - Update/Re-deploy all manifests"
	@echo "  make clean     - Remove everything"
	@echo "  make logs      - Show CUPS logs"
	@echo "  make shell     - Open shell in CUPS pod"
	@echo "  make status    - Show deployment status"

install:
	@echo "$(GREEN)=== Prerequisite Checks ===$(NC)"
	
	@echo "$(YELLOW)Checking LoadBalancer support...$(NC)"
	@if kubectl api-resources | grep -q service; then \
		LOADBALANCER_SUPPORT=$$(kubectl get svc --all-namespaces -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}' 2>/dev/null | grep -q . && echo "yes" || echo "no"); \
		if [ "$$LOADBALANCER_SUPPORT" = "yes" ]; then \
			echo "$(GREEN)✓ LoadBalancer is available$(NC)"; \
		else \
			echo "$(YELLOW)⚠ LoadBalancer may not be configured$(NC)"; \
			echo "  Continue anyway? (y/N)"; \
			read -r answer; \
			if [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
				echo "$(RED)Installation cancelled$(NC)"; \
				exit 1; \
			fi; \
		fi; \
	else \
		echo "$(RED)✗ Kubernetes API not accessible$(NC)"; \
		exit 1; \
	fi
	
	@echo "$(YELLOW)Checking StorageClass...$(NC)"
	@DEFAULT_SC=$$(kubectl get storageclass --no-headers -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\\.kubernetes\\.io/is-default-class 2>/dev/null | grep true | head -1); \
	if [ -n "$$DEFAULT_SC" ]; then \
		echo "$(GREEN)✓ Default StorageClass: $$(echo $$DEFAULT_SC | awk '{print $$1}')$(NC)"; \
	else \
		echo "$(RED)✗ No default StorageClass found$(NC)"; \
		echo "  A default StorageClass is required for PVC creation"; \
		exit 1; \
	fi
	
	@echo "$(YELLOW)Checking Pod Security Admission...$(NC)"
	@if kubectl api-resources | grep -q podsecuritypolicy; then \
		echo "$(YELLOW)⚠ PodSecurityPolicy detected$(NC)"; \
	elif kubectl get --raw /api/v1/namespaces/kube-system/configmaps/cluster-info 2>/dev/null | grep -q "admission"; then \
		echo "$(YELLOW)⚠ Pod Security Admission may be enabled$(NC)"; \
	else \
		echo "$(GREEN)✓ Pod Security Admission not enforced$(NC)"; \
	fi
	
	@echo ""
	@echo "$(GREEN)=== Starting Installation ===$(NC)"
	
	@echo "$(GREEN)Creating namespace...$(NC)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	
	@echo "$(GREEN)Applying pod security labels...$(NC)"
	@kubectl label namespace $(NAMESPACE) \
		pod-security.kubernetes.io/enforce=privileged \
		pod-security.kubernetes.io/enforce-version=latest \
		--overwrite=true 2>/dev/null || true
	
	@echo "$(GREEN)Creating admin secret...$(NC)"
	@if [ -z "$(ADMIN_PASSWORD)" ]; then \
		echo -n "Enter admin password (leave empty for random): "; \
		read user_password; \
		echo ""; \
		if [ -z "$$user_password" ]; then \
			ADMIN_PASSWORD=$$(openssl rand -base64 12); \
			echo "$(GREEN)Generated password: $$ADMIN_PASSWORD$(NC)"; \
		else \
			ADMIN_PASSWORD=$$user_password; \
		fi; \
	fi; \
	kubectl create secret generic $(APP_NAME)-admin \
		--from-literal=password=$${ADMIN_PASSWORD:-$(ADMIN_PASSWORD)} \
		-n $(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -
	
	@echo "$(GREEN)Applying manifests...$(NC)"
	@for file in pvc.yaml service.yaml deployment.yaml; do \
		if [ -f "$$file" ]; then \
			echo "Processing $$file..."; \
			envsubst < "$$file" | kubectl apply -n $(NAMESPACE) -f -; \
		fi; \
	done
	
	@echo "$(GREEN)Waiting for deployment rollout...$(NC)"
	@kubectl rollout status deployment $(APP_NAME) -n $(NAMESPACE) --timeout=120s
	
	@echo "$(GREEN)Waiting for pod to be ready...$(NC)"
	@kubectl wait --for=condition=ready pod -l app=$(APP_NAME) -n $(NAMESPACE) --timeout=120s
	
	@echo "$(GREEN)Initializing CUPS configuration...$(NC)"
	@if [ -f cupsd.conf ]; then \
		POD_NAME=$$(kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o jsonpath='{.items[0].metadata.name}'); \
		if [ -n "$$POD_NAME" ]; then \
			echo "Copying cupsd.conf to pod..."; \
			kubectl cp cupsd.conf $(NAMESPACE)/$$POD_NAME:/etc/cups/cupsd.conf; \
			echo "Configuration copied successfully"; \
			echo "Restarting CUPS to apply configuration..."; \
			kubectl exec -n $(NAMESPACE) $$POD_NAME -- /bin/sh -c 'kill -HUP `cat /var/run/cups/cupsd.pid`' 2>/dev/null || \
			kubectl exec -n $(NAMESPACE) $$POD_NAME -- /bin/sh -c 'pkill -HUP cupsd' 2>/dev/null || true; \
		fi; \
	else \
		echo "$(YELLOW)Skipping configuration copy - cupsd.conf not found$(NC)"; \
	fi
	
	@echo "$(GREEN)Waiting for LoadBalancer IP...$(NC)"
	@EXTERNAL_IP=""; \
	TIMEOUT=60; \
	COUNTER=0; \
	while [ -z "$$EXTERNAL_IP" ] && [ $$COUNTER -lt $$TIMEOUT ]; do \
		EXTERNAL_IP=$$(kubectl get svc $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
		if [ -z "$$EXTERNAL_IP" ]; then \
			EXTERNAL_IP=$$(kubectl get svc $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
		fi; \
		if [ -z "$$EXTERNAL_IP" ]; then \
			echo -n "."; \
			sleep 2; \
			COUNTER=$$((COUNTER + 1)); \
		fi; \
	done; \
	echo ""; \
	if [ -n "$$EXTERNAL_IP" ]; then \
		echo "$(GREEN)LoadBalancer endpoint: $$EXTERNAL_IP$(NC)"; \
	else \
		echo "$(YELLOW)⚠ No LoadBalancer IP assigned$(NC)"; \
		CLUSTER_IP=$$(kubectl get svc $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}'); \
		echo "  ClusterIP: $$CLUSTER_IP:631"; \
		echo "  Use: kubectl port-forward -n $(NAMESPACE) svc/$(APP_NAME) 631:631"; \
	fi
	
	@echo ""
	@echo "$(GREEN)=== Installation Complete ===$(NC)"
	@$(MAKE) status

update:
	@echo "$(GREEN)Updating deployment...$(NC)"
	@envsubst < deployment.yaml | kubectl apply -n $(NAMESPACE) -f -
	@kubectl rollout restart deployment $(APP_NAME) -n $(NAMESPACE)
	@kubectl rollout status deployment $(APP_NAME) -n $(NAMESPACE) --timeout=120s
	@echo ""
	@$(MAKE) status

clean:
	@echo "$(RED)=== WARNING: This will remove all CUPS resources ===$(NC)"
	@echo ""
	@if ! kubectl get namespace $(NAMESPACE) >/dev/null 2>&1; then \
		echo "$(YELLOW)Namespace '$(NAMESPACE)' does not exist. Nothing to clean.$(NC)"; \
		exit 0; \
	fi
	@echo "This will delete:"
	@echo "  - Deployment ($(APP_NAME))"
	@echo "  - Service ($(APP_NAME))"
	@echo "  - Persistent Volume Claim ($(APP_NAME)-data)"
	@echo "  - Secret ($(APP_NAME)-admin)"
	@echo "  - Namespace ($(NAMESPACE))"
	@echo ""
	@echo -n "Type '$(APP_NAME)' to confirm deletion: "
	@read -r confirmation; \
	if [ "$$confirmation" != "$(APP_NAME)" ]; then \
		echo "$(RED)Confirmation failed. Cleanup cancelled.$(NC)"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(RED)Removing CUPS...$(NC)"
	@for file in deployment.yaml service.yaml pvc.yaml; do \
		if [ -f "$$file" ]; then \
			envsubst < "$$file" | kubectl delete -n $(NAMESPACE) -f - --ignore-not-found=true; \
		fi; \
	done
	@kubectl delete secret $(APP_NAME)-admin -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(YELLOW)Removing namespace $(NAMESPACE)...$(NC)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)Cleanup complete$(NC)"

logs:
	@kubectl logs -l app=$(APP_NAME) -n $(NAMESPACE) --tail=100 -f

shell:
	@POD=$$(kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o jsonpath='{.items[0].metadata.name}'); \
	if [ -n "$$POD" ]; then \
		kubectl exec -it $$POD -n $(NAMESPACE) -- /bin/bash; \
	else \
		echo "$(RED)No running pods found$(NC)"; \
	fi

status:
	@echo ""
	@echo "$(GREEN)=== CUPS Status ===$(NC)"
	@echo ""
	@echo "$(YELLOW)Namespace:$(NC)     $(NAMESPACE)"
	@echo ""
	@POD_STATUS=$$(kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o jsonpath='{.items[0].status.phase}' 2>/dev/null); \
	POD_READY=$$(kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null); \
	POD_NAME=$$(kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ "$$POD_STATUS" = "Running" ] && [ "$$POD_READY" = "true" ]; then \
		echo "$(GREEN)✓$(NC) Pod:        Running ($$POD_NAME)"; \
	elif [ -n "$$POD_STATUS" ]; then \
		echo "$(YELLOW)⚠$(NC) Pod:        $$POD_STATUS ($$POD_NAME)"; \
	else \
		echo "$(RED)✗$(NC) Pod:        Not found"; \
	fi
	@PVC_STATUS=$$(kubectl get pvc $(APP_NAME)-data -n $(NAMESPACE) -o jsonpath='{.status.phase}' 2>/dev/null); \
	PVC_VOLUME=$$(kubectl get pvc $(APP_NAME)-data -n $(NAMESPACE) -o jsonpath='{.spec.volumeName}' 2>/dev/null); \
	if [ "$$PVC_STATUS" = "Bound" ]; then \
		echo "$(GREEN)✓$(NC) Storage:    Bound ($$PVC_VOLUME)"; \
	elif [ -n "$$PVC_STATUS" ]; then \
		echo "$(YELLOW)⚠$(NC) Storage:    $$PVC_STATUS"; \
	else \
		echo "$(RED)✗$(NC) Storage:    Not found"; \
	fi
	@SVC_IP=$$(kubectl get svc $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -z "$$SVC_IP" ]; then \
		SVC_IP=$$(kubectl get svc $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	fi; \
	if [ -n "$$SVC_IP" ]; then \
		echo "$(GREEN)✓$(NC) Access:     http://$$SVC_IP:631"; \
	else \
		CLUSTER_IP=$$(kubectl get svc $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.spec.clusterIP}' 2>/dev/null); \
		if [ -n "$$CLUSTER_IP" ]; then \
			echo "$(YELLOW)⚠$(NC) Access:     kubectl port-forward -n $(NAMESPACE) svc/$(APP_NAME) 631:631"; \
		else \
			echo "$(RED)✗$(NC) Access:     Not available"; \
		fi; \
	fi
	@echo ""
	@echo "$(GREEN)--- Details ---$(NC)"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@kubectl get deployment $(APP_NAME) -n $(NAMESPACE) 2>/dev/null | tail -n +2 | awk '{print "  " $$0}' || echo "  Not found"
	@echo ""
	@echo "$(YELLOW)Service:$(NC)"
	@kubectl get svc $(APP_NAME) -n $(NAMESPACE) 2>/dev/null | tail -n +2 | awk '{print "  " $$0}' || echo "  Not found"
	@echo ""
	@echo "$(YELLOW)PVC:$(NC)"
	@kubectl get pvc $(APP_NAME)-data -n $(NAMESPACE) 2>/dev/null | tail -n +2 | awk '{print "  " $$0}' || echo "  Not found"
	@echo ""
	@echo "$(YELLOW)Recent events (last 3):$(NC)"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' 2>/dev/null | tail -3 | awk '{print "  " $$0}' || echo "  No events"
	@echo ""