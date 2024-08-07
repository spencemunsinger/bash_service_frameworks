FROM ubuntu:22.04

# Define build-time variable
ARG RUN_DIR=/app

# Set environment variable to use in subsequent RUN commands
ENV RUN_DIR=${RUN_DIR}

# Set environment variable to prevent interactive configuration
ENV DEBIAN_FRONTEND=noninteractive

# Set the timezone you want to configure
ENV TZ=Etc/UTC

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install necessary dependencies
RUN apt-get update \
    && apt upgrade -y \
    && apt-get install -y tzdata \
    && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get update && apt-get install -y --fix-missing \
    sudo git curl python3 python3-pip wget bash openssh-client vim tree jq passwd awscli tar bzip2 gcc make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y

# Install Flask
RUN pip3 install Flask

# Create the directory and copy files
RUN mkdir -p ${RUN_DIR}

# Create user and group with home directory set to RUN_DIR
RUN groupadd -r chase-keys && useradd -r -g chase-keys -d ${RUN_DIR} chase-keys
RUN echo "chase-keys ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy the main script and entrypoint script
COPY _main.sh ${RUN_DIR}/_main.sh


# Ensure the bash script is executable
RUN chmod +x ${RUN_DIR}/_main.sh

# Change ownership of files to chase-keys user
RUN chown -R chase-keys:chase-keys ${RUN_DIR}

# Switch to non-root user
USER chase-keys

# Copy the Flask app into the container
COPY app.py /app/app.py

# Set the working directory
WORKDIR /app

# Expose the port that Flask will run on
EXPOSE 8080

# Run the Flask app
CMD ["python3", "app.py"]
