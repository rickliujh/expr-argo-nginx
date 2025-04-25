# Creates a new cluster
cluster_name=kind-expr

kind create cluster -n ${cluster_name}

# Installs ArgoCD

kubectl create namespace argocd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/install.yaml

# Installs Vault

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
kubectl create namespace vault
helm install vault hashicorp/vault -f kind/vault-config.yaml -n vault
helm list -n vault

# Initializes Vault
kubectl -n vault exec -it vault-0 -- vault status 
kubectl -n vault exec -it vault-0 -- vault operator init -n 1 -t 1 > vault-keys.txt
kubectl -n vault exec -it vault-0 -- vault status 
cat vault-keys.txt
