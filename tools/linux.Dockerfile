# Runs the test suite on Linux, in a container:
#
#   docker build -f tools/linux.Dockerfile -t godot-bend-linux .
#   docker run --rm godot-bend-linux
#
# The image carries clang, Bun and a headless Godot for the machine's
# architecture (x86_64 or arm64); the repository is copied in at build.
FROM ubuntu:24.04
ARG GODOT=4.6.3
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip clang libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN arch=$(uname -m | sed 's/aarch64/arm64/') \
    && curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT}-stable/Godot_v${GODOT}-stable_linux.${arch}.zip" \
    && unzip -q /tmp/godot.zip -d /opt \
    && mv /opt/Godot_v${GODOT}-stable_linux.${arch} /usr/local/bin/godot \
    && rm /tmp/godot.zip
WORKDIR /work
COPY . .
CMD ["tools/test.sh"]
