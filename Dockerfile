# User `bench-server` as a base image here
# because it is a minimum image of agent-bench-automation codes
FROM bench-server:latest AS base

RUN mkdir /etc/ciso-agent
WORKDIR /etc/ciso-agent

COPY requirements-dev.txt /etc/ciso-agent/requirements-dev.txt
# ciso-agent deps are many, so install them here (this reduce the time for installing code changes later)
RUN python -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt --no-cache-dir

#-----------------
# second stage
#-----------------
FROM bench-server:latest
COPY --from=base /etc/ciso-agent /etc/ciso-agent

WORKDIR /etc/ciso-agent

# need unzip for `aws` command
RUN apt update -y && apt install -y unzip ssh


# install `ansible-playbook`
RUN source .venv/bin/activate && pip install ansible-core jmespath kubernetes==31.0.0 --no-cache-dir
RUN source .venv/bin/activate && ansible-galaxy collection install kubernetes.core community.crypto
# install `jq`
RUN apt update -y && apt install -y jq
# install `kubectl`
RUN curl -LO https://dl.k8s.io/release/v1.31.0/bin/linux/$(dpkg --print-architecture)/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl
# install `aws` (need this for using kubectl against AWS cluster)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install
# install `opa`
RUN curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v1.0.0/opa_linux_$(dpkg --print-architecture)_static && \
    chmod +x ./opa && \
    mv ./opa /usr/local/bin/opa

COPY src /etc/ciso-agent/src
COPY pyproject.toml /etc/ciso-agent/pyproject.toml
COPY agent-harness.yaml /etc/ciso-agent/agent-harness.yaml

RUN source .venv/bin/activate && pip install -e /etc/ciso-agent --no-cache-dir

RUN echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# Agent is executed by agent-harness of agent-bench-automation, so workdir should be agent-benchmark
WORKDIR /etc/agent-benchmark
