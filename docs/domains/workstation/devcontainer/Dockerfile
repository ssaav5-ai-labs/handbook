FROM mcr.microsoft.com/devcontainers/python:3.12

RUN curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method standalone --opentofu-version 1.11.0 \
    && mv /usr/local/bin/tofu /usr/local/bin/opentofu

RUN SOPS_VERSION=3.10.2 \
    && curl -fsSL https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64 -o /usr/local/bin/sops \
    && chmod +x /usr/local/bin/sops

RUN AGE_VERSION=1.2.1 \
    && curl -fsSL https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz \
    | tar xz -C /usr/local/bin age/age age/age-keygen --strip-components=1

RUN K9S_VERSION=0.42.0 \
    && curl -fsSL https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz \
    | tar xz -C /usr/local/bin k9s

RUN chown -R vscode:vscode /home/vscode