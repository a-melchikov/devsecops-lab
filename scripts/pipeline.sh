#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-192.168.56.10:5000}"
IMAGE_NAME="${IMAGE_NAME:-my-app}"
DOCKERFILE="${1:-Dockerfile}"
TAG="${2:-latest}"
SEVERITY="${SEVERITY:-CRITICAL,HIGH}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
REPORT_DIR="${ROOT_DIR}/reports"
IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

mkdir -p "${REPORT_DIR}"

step() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf '\nPIPELINE FAILED: %s\n' "$*" >&2
  exit 1
}

step "1/4 Проверка Dockerfile"

trivy config \
  --exit-code 1 \
  --severity "${SEVERITY}" \
  "${APP_DIR}/${DOCKERFILE}" \
  || fail "небезопасный Dockerfile"

step "2/4 Сборка образа ${IMAGE}"

docker build --pull \
  -t "${IMAGE}" \
  -f "${APP_DIR}/${DOCKERFILE}" \
  "${APP_DIR}" \
  || fail "ошибка сборки"

step "3/4 Сканирование образа"

trivy image --quiet --format json \
  -o "${REPORT_DIR}/${IMAGE_NAME}-${TAG}.json" \
  "${IMAGE}" \
  || fail "не удалось получить отчёт Trivy"

trivy image \
  --exit-code 1 \
  --ignore-unfixed \
  --severity "${SEVERITY}" \
  "${IMAGE}" \
  || fail "обнаружены исправимые уязвимости ${SEVERITY}"

step "4/4 Публикация"

docker push "${IMAGE}" \
  || fail "не удалось опубликовать образ"

printf '\nPIPELINE OK: %s опубликован\n' "${IMAGE}"