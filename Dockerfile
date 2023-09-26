# Use the official Nginx image as the base image
FROM nginx:latest

# Copy the HTML file into the default Nginx web server directory
COPY index.html /usr/share/nginx/html

# Expose port 80 to the outside world
EXPOSE 80