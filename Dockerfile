#### base-image ####
FROM alpine:3.21 AS base-image

### Add Addtional Packages ###
RUN apk add --update --no-cache \
    aws-cli \
    bash \
    ca-certificates \
    curl \
    jq \
    git \
    make \
    openssl \
    npm \
    unzip \
    zlib

######## Terraform Set up ########
FROM base-image AS terraform-setup
ARG ARCH
ARG TF_VERSION="1.12.2"

RUN curl -L https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip -o /tmp/terraform.zip && \
    unzip /tmp/terraform.zip -d /tmp && \
    mv /tmp/terraform /usr/local/bin/ && \
    rm -f /tmp/terraform.zip && \
    chmod +x /usr/local/bin/terraform
RUN terraform -version

####### Kubernetes tools Setup #######
FROM base-image AS kubernetes-tools-setup
ARG ARCH
ARG K8S_VERSION="v1.30.4"
ARG HELM_VERSION="v3.17.2"
# Install kubectl
RUN curl -L https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl version --client
# Install Helm3
RUN mkdir -p /tmp/helm3 && \
    curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz | tar xz --strip-components=1 -C /tmp/helm3 && \
    mv /tmp/helm3/helm /usr/local/bin/helm3 && \
    rm -rf /tmp/helm3 && \
    chmod +x /usr/local/bin/helm3 && \
    helm3 version
# aws-iam-authenticator setup
RUN curl -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator && \
    chmod +x /usr/local/bin/aws-iam-authenticator

#### goss-setup #######
FROM base-image AS goss-setup
ARG ARCH
ARG GOSS_VERSION="0.4.9"
RUN curl -L https://github.com/goss-org/goss/releases/download/v${GOSS_VERSION}/goss-linux-${ARCH} -o /usr/local/bin/goss && \
    chmod +x /usr/local/bin/goss
####### jq-setup #######
FROM base-image AS jq-setup
ARG ARCH
ARG JQ_VERSION="1.7.1"
RUN curl -L https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${ARCH} -o /usr/local/bin/jq && \
    chmod +x /usr/local/bin/jq



####### Final Image #######
FROM base-image AS final-image
WORKDIR /usr/local/bin/
# copy terraform
COPY --from=terraform-setup /usr/local/bin/terraform /usr/local/bin/terraform1
RUN ln -s /usr/local/bin/terraform1 /usr/local/bin/terraform
# copy kubectl
COPY --from=kubernetes-tools-setup /usr/local/bin/kubectl /usr/local/bin/helm3 /usr/local/bin/aws-iam-authenticator ./
# copy goss
COPY --from=goss-setup /usr/local/bin/goss .
# copy jq
COPY --from=jq-setup /usr/local/bin/jq .
####### Golang setup #######
ARG ARCH
ARG GO_VERSION="1.23.4"
RUN apk add --update --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community go 
RUN go version

WORKDIR /work
# Set the entrypoint to bash
CMD ["/bin/bash"]