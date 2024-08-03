FROM node:18-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS deps
# RUN apk add --no-cache libc6-compat ----soluciona posibles errores
WORKDIR /usr/src/app

COPY package*.json yarn.lock* pnpm-lock.yaml* ./

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
   pnpm install --prod --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /usr/src/app
 #package json copiamos
COPY . .
COPY --from=deps /usr/src/app/node_modules ./node_modules

RUN --mount=type=bind,source=package.json,target=package.json \
--mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
--mount=type=cache,target=/root/.local/share/pnpm/store \
pnpm install --frozen-lockfile
RUN pnpm run build
# final
FROM base AS runner
WORKDIR /usr/src/app
ENV NODE_ENV production
# permisos
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# copiamos y creamos next
COPY --from=builder /usr/src/app/public ./public
RUN mkdir .next
RUN chown nextjs:nodejs .next
COPY --from=builder --chown=nextjs:nodejs /usr/src/app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /usr/src/app/.next/static ./.next/static
# finalizar subiendo el puerto
USER nextjs
EXPOSE 3000
ENV PORT 3000
CMD HOSTNAME="0.0.0.0" node server.js