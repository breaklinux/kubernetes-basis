FROM nginx:1.14.2-alpine
RUN set -ex && \
    apk -U upgrade && \
    apk add curl ca-certificates bash && \
    rm /etc/nginx/conf.d/default.conf && \
    rm /etc/nginx/nginx.conf  
COPY nginx.conf  /etc/nginx/ 
COPY default.conf.template /etc/nginx/conf.d/
