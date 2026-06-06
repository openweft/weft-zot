# Forked-build of project-zot/zot into a 4-arch openweft image
# (linux/amd64 + arm64 + riscv64 + loong64). Tracks upstream releases
# via the ZOT_VERSION build-arg ; bump = one ARG change + a `vX.Y.Z`
# git tag here.

ARG ZOT_VERSION=v2.1.0
ARG GO_VERSION=1.23
# Feature set : sync (registry mirroring, what we want for the egress
# cache pattern), search/ui (operator-facing), apikey/imagetrust
# (signing) ; drop "lint" / "scrub" which need extra non-Go deps.
# UI extension drops out : it embeds a pre-built SPA that needs a node
# stage to materialise ; out of scope for the wrapper build. Operators
# point a browser-friendly proxy (weft-webui) at the API instead.
ARG EXTENSIONS="sync,search,apikey,imagetrust,mgmt"

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS builder
ARG ZOT_VERSION EXTENSIONS TARGETOS TARGETARCH
WORKDIR /src
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth=1 --branch=${ZOT_VERSION} https://github.com/project-zot/zot.git .
ENV CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}
RUN go build -trimpath -tags="${EXTENSIONS}" -ldflags="-s -w" -o /out/zot ./cmd/zot

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /out/zot /usr/local/bin/zot
EXPOSE 5000
ENTRYPOINT ["/usr/local/bin/zot"]
CMD ["serve", "/etc/zot/config.json"]
