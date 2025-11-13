# ==============================================================================
# STAGE 1: Fetcher
# ==============================================================================
FROM ubuntu:24.04 AS fetcher

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl unzip

# 1. AWS CLI v2
# Instalamos en /usr/local/aws-cli. NO creamos el symlink en bin todavía para evitar problemas de copia.
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

# 2. AWS IAM Authenticator
RUN curl -o /usr/local/bin/aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-01-04/bin/linux/amd64/aws-iam-authenticator && \
    chmod +x /usr/local/bin/aws-iam-authenticator

# ==============================================================================
# STAGE 2: Assembler
# ==============================================================================
FROM ubuntu:24.04 AS assembler

ENV DEBIAN_FRONTEND=noninteractive

# Copiamos LA CARPETA de instalación de AWS, no el binario suelto
COPY --from=fetcher /usr/local/aws-cli /usr/local/aws-cli
# Copiamos el IAM authenticator (este sí es un binario estático único)
COPY --from=fetcher /usr/local/bin/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator

# Instalación masiva + Creación del symlink de AWS
RUN apt-get update && apt-get upgrade -y && \
    # Dependencias previas
    apt-get install -y --no-install-recommends \
    wget curl gnupg software-properties-common lsb-release ca-certificates && \
    # Repo Terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    # Instalación de herramientas
    apt-get update && apt-get install -y --no-install-recommends \
    terraform \
    htop atop nload tcpdump nano vim strace ltrace ethtool gcc git iotop less telnet \
    net-tools netsniff-ng screen tar docker.io python3 python3-pip python3-venv \
    ansible zip tzdata iputils-ping gettext-base nmap && \
    # --- CORRECCIÓN: Crear el symlink de AWS manualmente aquí ---
    ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws && \
    # Limpieza profunda
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ==============================================================================
# STAGE 3: Final (Squash)
# ==============================================================================
FROM scratch

COPY --from=assembler / /

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CMD ["/bin/bash"]