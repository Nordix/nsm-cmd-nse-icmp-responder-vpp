ARG VPP_VERSION=v23.10-rc0-167-g509e36aea
FROM ghcr.io/networkservicemesh/govpp/vpp:${VPP_VERSION} as go
COPY --from=golang:1.20.11 /usr/local/go/ /go
ENV PATH ${PATH}:/go/bin
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOBIN=/bin
ARG BUILDARCH
RUN rm -r /etc/vpp
RUN go install github.com/go-delve/delve/cmd/dlv@v1.21.0
ADD https://github.com/spiffe/spire/releases/download/v1.8.0/spire-1.8.0-linux-${BUILDARCH}-musl.tar.gz .
RUN tar xzvf spire-1.8.0-linux-${BUILDARCH}-musl.tar.gz -C /bin --strip=2 spire-1.8.0/bin/spire-server spire-1.8.0/bin/spire-agent

FROM go as build
WORKDIR /build
COPY go.mod go.sum ./
COPY ./internal/imports ./internal/imports
RUN go build ./internal/imports
COPY . .
RUN go build -o /bin/cmd-nse-icmp-responder-vpp .

FROM build as test
CMD go test -test.v ./...

FROM test as debug
CMD dlv -l :40000 --headless=true --api-version=2 test -test.v ./...

FROM ghcr.io/networkservicemesh/govpp/vpp:${VPP_VERSION} as runtime
COPY --from=build /bin/cmd-nse-icmp-responder-vpp /bin/cmd-nse-icmp-responder-vpp
ENTRYPOINT [ "/bin/cmd-nse-icmp-responder-vpp" ] 
