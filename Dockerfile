FROM ruby:3.4-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application files
COPY . .

# Create a non-root user and add to dialout group
RUN useradd -m appuser && \
    usermod -a -G dialout appuser && \
    chown -R appuser:appuser /app
USER appuser

# Command to run the application
CMD ruby setup_mqtt.rb && ruby mqtt_subscriber.rb
