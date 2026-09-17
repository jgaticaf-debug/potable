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

# Con Dockerfile las variables del servicio no llegan al build si no se
# declaran aqui. Vite la incrusta al compilar, asi que sin esto el panel sale
# apuntando a localhost por mas que este puesta en el proveedor.
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

FROM node:22-slim
WORKDIR /app

RUN npm install -g serve
COPY --from=construccion /app/dist ./dist
COPY arranque.sh ./
RUN chmod +x arranque.sh

CMD ["./arranque.sh"]
