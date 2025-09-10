# Build stage: Compile the application
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /build

# Copy pom.xml first for better caching
COPY pom.xml .
# Download dependencies (will be cached if pom.xml doesn't change)
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src/

# Build the application
RUN mvn package -DskipTests

# Runtime stage: Setup the actual runtime environment
FROM bellsoft/liberica-openjre-debian:21-cds

# Add metadata
LABEL maintainer="AmaliTech Training Academy" \
    description="Cloud Insight Pro Project" \
    version="1.0"

# Set default environment variables (can be overridden)
ENV SPRING_PROFILES_ACTIVE=production
ENV SERVER_PORT=8085

# Create a non-root user with proper home directory setup
RUN useradd -r -u 1001 -g root -m userservice && \
    mkdir -p /home/userservice/.config/jgit && \
    chown -R userservice:root /home/userservice && \
    chmod -R 755 /home/userservice

# Set HOME environment variable for JGit
ENV HOME=/home/userservice

WORKDIR /application

# Copy the extracted layers from the build stage
COPY --from=builder --chown=userservice:root /build/target/*.jar ./application.jar

# Install jq for JSON processing
RUN apt-get update && apt-get install -y jq && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY --chown=userservice:root entrypoint.sh ./entrypoint.sh

# Set executable permissions for entrypoint
RUN chmod +x ./entrypoint.sh

# Configure container
USER 1001
EXPOSE 8085

# Use entrypoint script that sources environment and starts the application
ENTRYPOINT ["bash", "-c", "source ./entrypoint.sh && exec java -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom -Djgit.java.io.tmpdir=/tmp -Djgit.useJGitInternalConfig=true -jar application.jar"]