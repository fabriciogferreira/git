# Keep in sync with @playwright/test in package.json
FROM mcr.microsoft.com/playwright:v1.63.0-jammy

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY playwright.config.ts ./
COPY tests ./tests

# Specs are also bind-mounted in compose for local iteration.
CMD ["npx", "playwright", "test", "--project=chromium"]
