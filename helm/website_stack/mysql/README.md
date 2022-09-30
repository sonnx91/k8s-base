# cách cài đặt redis:


# Để đảm bảo redis không bị mất dữ liệu thì cần có storage classs và điền tên vào phần dòng storage class trong file mysql.yml sau đó chạy các command
```
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm install mysql bitnami/mysql --version 9.3.4 -f mysql.yaml

```