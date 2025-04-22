FROM nginx:1.25-alpine

# Remove the stock default, we'll generate ours
RUN rm /etc/nginx/conf.d/default.conf

# Put template anywhere; we'll envsubst it at container start
COPY ping.conf.template /etc/nginx/ping.conf.template

# Run envsubst then start nginx
CMD /bin/sh -c 'envsubst < /etc/nginx/ping.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g "daemon off;"'
