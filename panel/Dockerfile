# Nixpacks no lograba instalar el binario nativo de tailwind y el build moria
# con "Cannot find native binding". Aqui la imagen y el comando de instalacion
# son explicitos, asi que no depende de lo que el proveedor decida armar.

FROM node:22-slim AS construccion
WORKDIR /app

COPY package.json package-lock.json .npmrc ./
# install y no ci: ci instala el lock al pie de la letra y ahi se pierden los
# binarios opcionales de la plataforma. Este los vuelve a resolver.
RUN npm install --include=optional

COPY . .
RUN npm run build

FROM node:22-slim
WORKDIR /app

RUN npm install -g serve
COPY --from=construccion /app/dist ./dist

# -s reescribe todo a index.html: sin eso, entrar directo a /alertas da 404
# porque ese archivo no existe, las rutas las resuelve el router del navegador.
CMD ["sh", "-c", "serve dist -s -l ${PORT:-3000}"]
