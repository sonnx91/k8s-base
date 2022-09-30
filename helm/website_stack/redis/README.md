# cách cài đặt redis:


# Để đảm bảo redis không bị mất dữ liệu thì cần có storage class và điền vào  file redis.yaml
```

helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm upgrade --install redis  --version 16.9.2 -f redis.yaml

```