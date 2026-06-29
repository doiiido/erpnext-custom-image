ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG FRAPPE_BRANCH=version-16
ARG PYTHON_VERSION=3.14.6
ARG NODE_VERSION=24.16.0
ARG APPS_JSON_BASE64

FROM ghcr.io/frappe/base:${FRAPPE_BRANCH} AS base

FROM ghcr.io/frappe/build:${FRAPPE_BRANCH} AS builder

ARG APPS_JSON_BASE64
ARG FRAPPE_PATH
ARG FRAPPE_BRANCH
ARG NODE_VERSION
ARG PYTHON_VERSION

RUN export APPS_JSON_BASE64=${APPS_JSON_BASE64} && \
    bench init \
      --frappe-branch=${FRAPPE_BRANCH} \
      --frappe-path=${FRAPPE_PATH} \
      --no-procfile \
      --no-backups \
      --skip-redis-config-generation \
      --verbose \
      /home/frappe/frappe-bench && \
    cd /home/frappe/frappe-bench && \
    echo ${APPS_JSON_BASE64} | base64 -d > /apps.json && \
    bench get-app --from-apps-json /apps.json && \
    echo "{}" > sites/common_site_config.json && \
    find apps -mindepth 1 -path "*/doctype/*/*" -not -name "*.py" -not -name "*.json" -not -name "*.csv" -not -name "*.md" -delete && \
    find apps -mindepth 1 -path "*/boilerplate/*" -delete && \
    bench build --production

FROM base AS runner

COPY --from=builder /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/sites/assets", \
  "/home/frappe/frappe-bench/logs" \
]

CMD [ \
  "/home/frappe/frappe-bench/env/bin/gunicorn", \
  "--chdir=/home/frappe/frappe-bench/sites", \
  "--bind=0.0.0.0:8000", \
  "--threads=4", \
  "--workers=2", \
  "--worker-class=gthread", \
  "--timeout=120", \
  "frappe.app:application" \
]