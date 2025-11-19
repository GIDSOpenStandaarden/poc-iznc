FROM mcr.microsoft.com/dotnet/sdk:8.0

LABEL maintainer="roland@headease.nl"

# Build arguments for version control
ARG PUBLISHER_VERSION=2.0.15
ARG SUSHI_VERSION=3.16.5

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
        make \
        jq \
        default-jdk \
        python3 \
        python3-pip \
        python3-yaml \
        graphviz \
        jekyll \
        nodejs \
        npm \
        wget \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Install Firely Terminal
RUN dotnet tool install -g firely.terminal

# Install FHIR Shorthand (SUSHI)
RUN npm install -g fsh-sushi@${SUSHI_VERSION}

# Set up working directory
RUN mkdir "/src"
WORKDIR /src

# Download IG Publisher
RUN curl -L https://github.com/HL7/fhir-ig-publisher/releases/download/${PUBLISHER_VERSION}/publisher.jar \
    -o /usr/local/publisher.jar

# Set up Saxon for FHIR IG Publisher
ENV saxonPath=/root/.ant/lib/
RUN mkdir -p ${saxonPath} && \
    wget https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/11.4/Saxon-HE-11.4.jar \
        -O ${saxonPath}/saxon-he-11.4.jar && \
    wget https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/5.3.0/xmlresolver-5.3.0.jar \
        -O ${saxonPath}/xmlresolver-5.3.0.jar

# Environment variables
ENV FHIR_EMAIL=roland@headease.nl
ENV DEBUG=1
ENV PATH="${PATH}:/root/.dotnet/tools"

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
