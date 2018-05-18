FROM perfectlysoft/perfectassistant:latest
LABEL Description="Docker image for Swift + Perfect on a Google App Engine flexible environment."

ARG DEBIAN_FRONTED=noninteractive
ENV DEBIAN_FRONTEND noninteractive
# Get extra dependencies for Perfect
RUN apt-get update && apt-get install -y \
openssl \
libssl-dev \
uuid-dev

RUN openssl version -a
# RUN sudo apt-get --assume-yes install software-properties-common
# RUN sudo add-apt-repository ppa:0k53d-karl-f830m/openssl
# RUN sudo apt-get update
# RUN sudo apt-get --assume-yes install openssl
# RUN openssl version -a

# Expose default port for App Engine
EXPOSE 8080

# Copy sources
RUN mkdir /root/MaterialAutomation
ADD Package.swift /root/MaterialAutomation
ADD Sources /root/MaterialAutomation/Sources
ADD material-ci-app.2018-05-09.private-key.pem /root/MaterialAutomation

# Build the app
RUN cd /root/MaterialAutomation && ls -la && cd Sources && ls -la
RUN cd /root/MaterialAutomation && swift build

# Run the app
USER root
CMD ["/root/MaterialAutomation/.build/debug/MaterialAutomation"]
