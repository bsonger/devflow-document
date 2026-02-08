### Build Static Site
FROM ghcr.io/gohugoio/hugo:v0.147.6 AS builder
WORKDIR /src
COPY --chown=hugo:hugo . .
ARG HUGO_BASEURL=/
RUN hugo --baseURL "${HUGO_BASEURL}" --gc --minify

### Serve with Nginx
FROM docker.io/nginx:1.27.4-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
USER nginx
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
