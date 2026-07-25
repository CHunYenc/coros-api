# syntax=docker/dockerfile:1

ARG NODE_VERSION=24.18.0

#############################################
# Base: enable pnpm via corepack
#############################################
FROM node:${NODE_VERSION}-alpine AS base
RUN corepack enable
WORKDIR /app

#############################################
# Dependencies: install full deps (incl. dev) for building
#############################################
FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

#############################################
# Build: compile TypeScript with swc via nest build
#############################################
FROM deps AS build
COPY tsconfig.json nest-cli.json ./
COPY src ./src
RUN pnpm build

#############################################
# Production dependencies only
#############################################
FROM base AS prod-deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile --prod

#############################################
# Runtime image
#############################################
FROM node:${NODE_VERSION}-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./

# Output directory for exported activities/schedules; mount a volume here.
RUN mkdir -p /data
VOLUME ["/data"]

ENTRYPOINT ["node", "dist/main"]
CMD ["export-activities", "--out", "/data"]

# docker run --rm --env-file .env -v "$PWD/out:/data" coros-api export-activities --fromDate 2026-07-15 --toDate 2026-07-25 --out /data
# docker run -v "$PWD/out:/data" coros-api export-activities --fromDate 2026-07-15 --toDate 2026-07-25 --out /data