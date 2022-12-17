FROM node:16-bullseye-slim as builder

LABEL maintainer="Kagurazaka Mizuki"

WORKDIR /app
COPY . /app

ENV IS_DOCKER=true
ARG BINARY_TARGETS="[\"linux-musl\"]"
ARG USE_CHINA_MIRROR=0

RUN apt-get -y update \
  && apt-get install -y git python3 apt-transport-https ca-certificates build-essential openssl \
  && ln -s /usr/bin/python3 /usr/bin/python \
  && openssl version -a \
  && npm install pnpm@7 -g \
  && pnpm install --unsafe-perm \
  && pnpm build


FROM node:16-alpine as app

WORKDIR /app


COPY --from=0 /app/package.json ./
COPY --from=0 /app/.npmrc ./
COPY --from=0 /app/LICENSE ./
COPY --from=0 /app/pnpm-lock.yaml ./
COPY --from=0 /app/pnpm-workspace.yaml ./

COPY --from=0 /app/packages/nodestatus-cli/package.json ./packages/nodestatus-cli/

COPY --from=0 /app/packages/nodestatus-server/package.json ./packages/nodestatus-server/
COPY --from=0 /app/packages/nodestatus-server/build ./packages/nodestatus-server/build
COPY --from=0 /app/packages/nodestatus-server/scripts ./packages/nodestatus-server/scripts
COPY --from=0 /app/packages/nodestatus-server/prisma ./packages/nodestatus-server/prisma

COPY --from=0 /app/web/classic-theme/package.json ./web/classic-theme/
COPY --from=0 /app/web/hotaru-theme/package.json ./web/hotaru-theme/
COPY --from=0 /app/web/hotaru-admin/package.json ./web/hotaru-admin/
COPY --from=0 /app/web/utils/package.json ./web/utils/

ENV IS_DOCKER=true
ENV NODE_ENV=production
ARG USE_CHINA_MIRROR=0
RUN apk add --no-cache --virtual .build-deps git make gcc g++ python3 openssl \
  && npm install pm2 pnpm@6 prisma -g \
  && pnpm install --prod --frozen-lockfile \
  && npm cache clean --force \
  && apk del .build-deps

EXPOSE 35601

CMD ["pm2-runtime", "start", "npm" , "--", "start"]
