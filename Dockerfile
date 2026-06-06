# Forked-build of project-zot/zot into a 4-arch openweft image
# (linux/amd64 + arm64 + riscv64 + loong64). Tracks upstream releases
# via the ZOT_VERSION build-arg ; bump = one ARG change + a `vX.Y.Z`
# git tag here.

ARG ZOT_VERSION=v2.1.0
ARG GO_VERSION=1.23
# Feature set : sync (registry mirroring, what we want for the egress
# cache pattern), search/ui (operator-facing), apikey/imagetrust
# (signing) ; drop "lint" / "scrub" which need extra non-Go deps.
# Drop two extensions vs upstream defaults :
#   - `ui` embeds a pre-built SPA (npm/vite stage upstream) — out of
#     scope for the wrapper, weft-webui talks to the API directly.
#   - `imagetrust` pulls containers/image's GPG mechanism which needs
#     cgo (libgpgme) ; we lose Cosign+Notary verification but keep
#     transport TLS, signed-by-key apikey, and the sync mirror — the
#     primary openweft use case is egress-cache, not signing.
#
# `containers_image_openpgp` is a transitive build tag that switches
# containers/image's signature backend from gpgme (cgo) to
# golang.org/x/crypto/openpgp (pure Go). Mandatory or the sync/mgmt
# packages fail to compile under CGO=0 ; validated locally on
# amd64+arm64+riscv64+loong64.
ARG EXTENSIONS="containers_image_openpgp,sync,search,apikey,mgmt"

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
