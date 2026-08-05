# 1. Use an ultra-lightweight, secure Linux web server baseline image
FROM nginx:alpine

# 2. Copy our application web file into the container's internal web hosting folder
COPY index.html /usr/share/nginx/html/

# 3. Inform the host network layer that this container listens on Port 80
EXPOSE 80
