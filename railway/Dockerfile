# syntax=docker/dockerfile:1
# Combined image for Railway: runs the export, then uploads the result to
# Google Drive with rclone, all in a single Cron Job service (Railway cron
# jobs don't support chaining "service A then service B").
#
# No RUN --mount=type=cache here: Railway's builder requires cache mount IDs
# to be prefixed with a hardcoded `s/<railway-service-id>-`, which would tie
# this file to one specific service. Railway still caches image layers
# between builds without it.

ARG NODE_VERSION=24.18.0

FROM node:${NODE_VERSION}-alpine AS base
RUN corepack enable
WORKDIR /app

FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches
RUN pnpm install --frozen-lockfile

FROM deps AS build
COPY tsconfig.json nest-cli.json ./
COPY src ./src
RUN pnpm build

FROM base AS prod-deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches
RUN pnpm install --frozen-lockfile --prod

FROM node:${NODE_VERSION}-alpine AS runtime
RUN apk add --no-cache rclone
WORKDIR /app
ENV NODE_ENV=production

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
COPY railway/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
