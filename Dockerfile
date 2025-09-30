# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM swift:6.1 AS builder
ARG TARGETPLATFORM
ARG SWIFT_SDK_ID
WORKDIR /workspace

# Install Swift static SDK (version must match base toolchain)
RUN swift sdk install \
  https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
  --checksum 111c6f7d280a651208b8c74c0521dd99365d785c1976a6e23162f55f65379ac6

COPY . /workspace

# Install `file` utility
RUN apt-get update && apt-get install -y --no-install-recommends file \
 && rm -rf /var/lib/apt/lists/*

# Map platform -> correct SDK ID if not provided
RUN if [ -z "$SWIFT_SDK_ID" ]; then \
      case "$TARGETPLATFORM" in \
        linux/amd64) SWIFT_SDK_ID=x86_64-swift-linux-musl ;; \
        linux/arm64) SWIFT_SDK_ID=aarch64-swift-linux-musl ;; \
        *) echo "Unsupported TARGETPLATFORM: $TARGETPLATFORM" && exit 1 ;; \
      esac; \
    fi && \
    echo "Using Swift SDK: $SWIFT_SDK_ID" && \
    swift build -c release --swift-sdk "$SWIFT_SDK_ID" -Xswiftc -Osize && \
    cp ".build/$SWIFT_SDK_ID/release/subtree" /workspace/subtree && \
    file /workspace/subtree

FROM scratch AS runner
COPY --from=builder /workspace/subtree /usr/bin/subtree
ENTRYPOINT ["/usr/bin/subtree"]
CMD ["--help"]

FROM scratch AS output
COPY --from=builder /workspace/subtree /subtree