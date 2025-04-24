## ConfigMap and Secrets

Creates "ConfigMap" by below command in the project root directory.

```
kubectl -n nginx create cm nginx-conf --from-file default.conf=ng-proxy-basic-auth.conf
```

Creates "Secrets" by below command in the project root directory.

```
kubectl -n nginx create secret generic nginx-basic-auth --from-file .htpasswd
```

Or, apply them once by below command in the project root directory.

```
kubectl -n nginx apply -f k8s/configmaps.yaml
```
