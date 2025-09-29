# syntax=docker/dockerfile:1

# Base image and static SDK have to be updated together.
FROM --platform=$BUILDPLATFORM swift:6.1 AS builder
WORKDIR /workspace

# Install Swift static SDK for better portability
RUN swift sdk install \
	https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
	--checksum 111c6f7d280a651208b8c74c0521dd99365d785c1976a6e23162f55f65379ac6

# Copy source files
COPY . /workspace

# Build with static SDK and cross-compilation support
ARG TARGETPLATFORM
RUN --mount=type=cache,target=/workspace/.build,id=build-$TARGETPLATFORM \
    echo "Building for platform: $TARGETPLATFORM" && \
    swift sdk list && \
    case "$TARGETPLATFORM" in \
      "linux/amd64") \
        swift build -c release --swift-sdk swift-6.1-RELEASE_static-linux-0.0.1 --arch x86_64 && \
        cp /workspace/.build/*/release/subtree /workspace/subtree ;; \
      "linux/arm64") \
        swift build -c release --swift-sdk swift-6.1-RELEASE_static-linux-0.0.1 --arch arm64 && \
        cp /workspace/.build/*/release/subtree /workspace/subtree ;; \
      *) \
        echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac

# Final minimal runtime image
FROM scratch AS runner
COPY --from=builder /workspace/subtree /usr/bin/subtree
ENTRYPOINT [ "/usr/bin/subtree" ]
CMD ["--help"]

# Output stage for CI extraction
FROM scratch AS output
COPY --from=builder /workspace/subtree /subtree
