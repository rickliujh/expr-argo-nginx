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
# Uncomment this will use Vault development mode to simplify the setup
# helm install vault hashicorp/vault -n vault --set "server.dev.enabled=true"
helm install vault hashicorp/vault -f kind/vault-config.yaml -n vault
helm list -n vault

# Initializes Vault
kubectl -n vault exec -it vault-0 -- vault status 
kubectl -n vault exec -it vault-0 -- vault operator init -n 1 -t 1 > vault-keys.txt
kubectl -n vault exec -it vault-0 -- vault status 
cat vault-keys.txt

# Configures Vault Role for injection

root_token=$(grep "Initial Root Token" ./vault-keys.txt | awk '{print $NF}' | tr -d '\r' | sed 's/\x1b\[[0-9;]*m//g')
kubectl -n vault exec -it vault-0 -- sh -c "vault login ${root_token}"

# Enable k8s authentication
kubectl -n vault exec -it vault-0 -- vault auth enable kubernetes

kubectl -n vault exec -it vault-0 -- sh -c 'vault write auth/kubernetes/config \
   token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
   kubernetes_host=https://${KUBERNETES_PORT_443_TCP_ADDR}:443 \
   kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'

# Creates and applies policy
kubectl -n vault exec -it vault-0 -- sh -c 'cat <<EOF > /home/vault/read-policy.hcl
path "secret*" {
  capabilities = ["read"]
}
EOF'

kubectl -n vault exec -it vault-0 -- vault policy write read-policy /home/vault/read-policy.hcl

kubectl -n vault exec -it vault-0 -- vault write auth/kubernetes/role/vault-role \
   bound_service_account_names=vault \
   bound_service_account_namespaces=vault \
   policies=read-policy \
   ttl=1h

# for nginx
htpasswd=$(cat ./.htpasswd)
kubectl -n vault exec -it vault-0 -- vault secrets enable -path=kv kv-v2
kubectl -n vault exec -it vault-0 -- vault secrets list
kubectl -n vault exec -it vault-0 -- vault kv put kv/nginx/basic-auth htpasswd="$htpasswd"
kubectl -n vault exec -it vault-0 -- sh -c 'cat <<EOF > /home/vault/ng-read-policy.hcl
path "kv/data/nginx/*" {
  capabilities = ["read"]
}
EOF'
kubectl -n vault exec -it vault-0 -- vault policy write ng-read-policy /home/vault/ng-read-policy.hcl
kubectl -n vault exec -it vault-0 -- vault write auth/kubernetes/role/nginx-role \
   bound_service_account_names=default\
   bound_service_account_namespaces=nginx\
   policies=ng-read-policy \
   ttl=1h
