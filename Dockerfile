# Copyright 2018 the Material Automation authors. All Rights Reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM perfectlysoft/perfectassistant:latest
LABEL Description="Material Automation"

ARG DEBIAN_FRONTED=noninteractive
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
openssl \
libssl-dev \
uuid-dev

RUN openssl version -a

EXPOSE 8080

# Copy sources
RUN mkdir /root/MaterialAutomation
ADD Package.swift /root/MaterialAutomation
ADD Sources /root/MaterialAutomation/Sources
ADD GithubKey.pem /root/MaterialAutomation

# Build the app
RUN cd /root/MaterialAutomation && ls -la && cd Sources && ls -la
RUN cd /root/MaterialAutomation && swift build

# Run the app
USER root
CMD ["/root/MaterialAutomation/.build/debug/MaterialAutomation"]
