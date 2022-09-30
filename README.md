# Getting started

> Install and deploy K8s Cluster

## Install

### Config host

`Cập nhật nội dung file hosts`

- Node master

```text
[masters]
master_1 ansible_host=aws.codihaus.k8s.master
```

- Node worker

```text
[workers]
worker_1 ansible_host=aws.codihaus.k8s.node.1
worker_2 ansible_host=aws.codihaus.k8s.node.2
worker_3 ansible_host=aws.codihaus.k8s.node.3
```

### Run bash install

```shell
ansible-playbook install-k8s.yml --inventory=hosts
```

### Check installed

```shell
kubectl get nodes

NAME            STATUS   ROLES    AGE   VERSION
cp-k8s-master   Ready    master   16h   v1.18.20
cp-k8s-node-1   Ready    worker   16h   v1.18.20
cp-k8s-node-2   Ready    worker   16h   v1.18.20
cp-k8s-node-3   Ready    worker   16h   v1.18.20
```

> Tới đây là đã triển khai được 1 cluster K8s giữa Master - Worker Node

## Deploy Application

Bắt đầu triển khai ứng dụng vào K8s Cluster. Tại thư mục helm/website_stack để thực thi các lệnh bên dưới

### Deploy nginx

```shell
make ingress
```

### Gitlab Registry credentials

Readmore <https://chris-vermeulen.com/using-gitlab-registry-with-kubernetes/>

Tạo file docker.config.json và điền vào các biến số, theo dõi liên kết để nhận biến số

```json
{
    "auths": {
        "https://registry.gitlab.com": {
            "username": "<>",
            "password": "<>",
            "email": "<>",
            "auth": "<>",
        }
    }
}
```

Chạy lệnh bên dưới và copy token vào file `.yaml`. Thay thế cho `BASE_64_ENCODED_DOCKER_FILE`

```shell
cat docker.config.json | base64
```

```shell
kubectl apply -f gitlab-registry-credentials.yaml
```

| Parameter               | Description                 | Default     |
| ----------------------- | --------------------------- | ----------- |
| `metadata.name`         |                             | `""`        |
| `metadata.namespace`    |                             | `"default"` |
| `data.dockerconfigjson` | BASE_64_ENCODED_DOCKER_FILE | `""`        |

### Template in local to check yaml

Sử dụng để test template dưới local

```shell
helm template cms ./application -f cms.yaml
helm template frontend ./application -f frontend.yaml
```

### Deploy frontend

The following table lists the configurable parameters of the chart and their default values.

| Parameter          | Description                                                                  | Default        |
| ------------------ | ---------------------------------------------------------------------------- | -------------- |
| `image.repository` | Replace frontend image id or image path here                                 | `""`           |
| `image.tag`        | Image tag, will override the default tag derived from the chart app version. | `""`           |
| `image.pullPolicy` | Image pull policy.                                                           | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets.`(gitlab-registry-credentials.metadata.name)`             | `frontend`     |
| `applicationName`  |                                                                              | `""`           |
| `envVars.*`        | Set environment params for application                                       | `[]`           |

```shell
helm upgrade --install frontend ./application -f frontend.yaml
NAME: frontend
LAST DEPLOYED: Wed Sep 21 11:42:49 2022
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

### Deploy cms

```shell
helm upgrade --install backend ./application -f cms.yaml
NAME: backend
LAST DEPLOYED: Wed Sep 21 11:18:11 2022
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

### Redeploy applications

```shell
kubectl rollout restart deploy frontend
```

```shell
kubectl rollout restart deploy cms
```

## Utility Commands

> Note: Sử dụng cho chart tự viết

Reference here: <https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#use-case>

### Change image of deployment

```shell
kubectl set image --record deployment/prod-phs-backend main=<container_repo_url>:<container_tag> --namespace default
```

Command này chỉ đúng khi <container_tag> có thai đổi

### Rollout restart deployment

```shell
kubectl rollout restart deployment/prod-phs-backend --namespace default
```

Command này buộc kubernetes phải tắt pod của deployment và tạo pod mới. Nếu set imagePullPolicy: Always thì sẽ luôn pull image mới nhất từ container registry về

### Watch rollout status

```shell
kubectl rollout status deployment/prod-phs-backend --namespace default
```

### Rolling Back to a Previous Revision

```sheel
kubectl rollout undo deployment/prod-phs-backend --namespace default
```

Command này cho phép rollback về version trước của deployment, nhưng sẽ không hoạt động nếu container_tag của version liền kế trước giống với version hiện tại.

## Status developing

| env           | install k8s-cluster   | Kube deploy           |
| ------------- | --------------------- | --------------------- |
| local         | :white_check_mark:    | :white_check_mark:    |
| ec2 instances | :white_check_mark:    | :white_check_mark:    |
| on Premise    | :black_square_button: | :black_square_button: |
