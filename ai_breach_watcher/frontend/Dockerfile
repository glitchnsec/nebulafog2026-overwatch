FROM node:22-slim AS base
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install

COPY . .

# Dev target — Vite dev server with HMR
FROM base AS dev
EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]

# Prod target — build static files and serve with lightweight server
FROM base AS prod
RUN npm run build && npm install -g serve
EXPOSE 3000
CMD ["serve", "-s", "dist", "-l", "3000"]
