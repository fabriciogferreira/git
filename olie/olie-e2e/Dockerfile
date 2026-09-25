# Keep in sync with ../docker-workspace/e2e/Dockerfile (@playwright/test version).
# Workspace stack builds from this file (build context is this repo).
FROM mcr.microsoft.com/playwright:v1.63.0-jammy

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY playwright.config.ts ./
COPY tests ./tests
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Specs are also bind-mounted in compose for local iteration.
# Entrypoint fixes bind-mount permissions, then runs as pwuser.
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
