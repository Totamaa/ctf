# Etape 1 : Builder le site static avec Python
FROM python:3.9-alpine as builder

WORKDIR /app
COPY . .

# Installation des dépendances
RUN pip install mkdocs-material

# Génération du site (crée le dossier /app/site)
RUN mkdocs build

# Etape 2 : Servir avec Nginx (image finale minuscule)
FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copier le site généré vers Nginx
COPY --from=builder /app/site /usr/share/nginx/html

# La config par défaut de Nginx suffit pour du statique
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
