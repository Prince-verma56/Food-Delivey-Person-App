FROM ghcr.io/cirruslabs/flutter:3.13.1

WORKDIR /app

# Note: This Dockerfile is intended for CI/CD or reproducible APK builds, 
# not for daily development. 
# Daily development should be done on your host machine with `flutter run`.

# Copy dependency files first
COPY pubspec.* ./
RUN flutter pub get

# Copy source code
COPY . .

# Ensure permissions
RUN sudo chown -R cirrus:cirrus /app

# Default command compiles the APK
CMD ["flutter", "build", "apk", "--release"]
