#!/usr/bin/env bash
# E-Duud backend-ийг minikube дээр бүтнээр нь асаана.
#   ./k8s/minikube.sh          # асаах (build + deploy + seed)
#   ./k8s/minikube.sh build    # зөвхөн image дахин build хийж backend-ийг restart
#   ./k8s/minikube.sh down     # namespace устгах (DB өгөгдөл мөн устна)
set -euo pipefail
cd "$(dirname "$0")/.."

NS=eduud
IMAGE=eduud-backend:local

ensure_minikube() {
  if ! minikube status >/dev/null 2>&1; then
    echo "==> minikube асааж байна"
    minikube start --cpus=4 --memory=6g --driver=docker
  fi
}

build_image() {
  echo "==> Image-ийг minikube дотор build хийж байна"
  # minikube нь containerd runtime-тэй тул docker-env биш `minikube image build` ашиглана
  minikube image build -t "$IMAGE" .
}

case "${1:-up}" in
  up)
    ensure_minikube
    build_image
    echo "==> Manifest apply"
    kubectl apply -f k8s/00-namespace.yaml
    kubectl apply -f k8s/10-postgres.yaml -f k8s/20-kafka.yaml -f k8s/30-backend.yaml
    kubectl -n $NS rollout status statefulset/postgres --timeout=180s
    kubectl -n $NS rollout status statefulset/kafka --timeout=300s
    kubectl -n $NS rollout status deployment/backend --timeout=300s
    echo "==> Seed"
    kubectl -n $NS delete job seed --ignore-not-found
    kubectl apply -f k8s/40-seed-job.yaml
    kubectl -n $NS wait --for=condition=complete job/seed --timeout=300s
    IP=$(minikube ip)
    echo
    echo "Бэлэн:"
    echo "  API:       http://$IP:30000   (health: /actuator/health)"
    echo "  Socket.IO: http://$IP:30001"
    echo "  (macOS docker driver дээр IP руу шууд хандаж болохгүй бол: minikube service backend -n $NS --url"
    echo "   эсвэл: kubectl -n $NS port-forward svc/backend 3000:3000 3001:3001)"
    ;;
  build)
    ensure_minikube
    build_image
    kubectl -n $NS rollout restart deployment/backend
    kubectl -n $NS rollout status deployment/backend --timeout=300s
    ;;
  down)
    kubectl delete namespace $NS --ignore-not-found
    ;;
  *)
    echo "Хэрэглээ: $0 [up|build|down]"; exit 1 ;;
esac
