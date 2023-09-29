# SimpleWebApp

This is a simple web application hosting a static home page on ECS behind a load balancer.

the application is available at this endpoint : http://simple-webapp-alb-2002736658.eu-west-1.elb.amazonaws.com/

the docker image is build using the Docker file and nginx.conf in githubaction using the build-push.yml pipeline

The infrastructure is deployed using terraform specified in the ecs.tf file and using de deploy.yml pipeline