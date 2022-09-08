
# image
TAG ?= 0.0.1

# certs

CONFIG_PATH=${HOME}/.proglog/

.PHONY: config
config:
	mkdir -p ${CONFIG_PATH}

$(CONFIG_PATH)/model.conf:
	cp test/model.conf $(CONFIG_PATH)/model.conf

$(CONFIG_PATH)/policy.csv:
	cp test/policy.csv $(CONFIG_PATH)/policy.csv 

.PHONY: gencert
gencert:
	cfssl gencert \
		-initca test/ca-csr.json | cfssljson -bare ca
	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=test/ca-config.json \
		-profile=server \
		test/server-csr.json | cfssljson -bare server
	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=test/ca-config.json \
		-profile=client \
		-cn="root" \
		test/client-csr.json | cfssljson -bare root-client
	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=test/ca-config.json \
		-profile=client \
		-cn="nobody" \
		test/client-csr.json | cfssljson -bare nobody-client
	mv *.pem *.csr ${CONFIG_PATH}

# dev

init:
	go mod init github.com/jonathanve/proglog

clean:
	go mod tidy

install:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
	go install github.com/cloudflare/cfssl/cmd/cfssl@v1.6.1
	go install github.com/cloudflare/cfssl/cmd/cfssljson@v1.6.1

deps:
	go get google.golang.org/grpc@v1.48.0
	go get github.com/grpc-ecosystem/go-grpc-middleware@v1.3.0
	go get google.golang.org/protobuf/proto
	go get github.com/stretchr/testify/require
	go get github.com/tysonmote/gommap
	go get github.com/casbin/casbin@v1.9.1
	go get go.uber.org/zap@v1.21.0
	go get go.opencensus.io@v0.23.0
	go get github.com/hashicorp/serf@v0.8.5
	go get github.com/travisjeffery/go-dynaport
	go get github.com/soheilhy/cmux
	go get github.com/hashicorp/raft@v1.1.1
	go mod edit -replace github.com/hashicorp/raft-boltdb=github.com/travisjeffery/raft-boltdb@v1.0.0
	go get github.com/spf13/cobra
	go get github.com/spf13/viper

stubs:
	protoc api/v1/*.proto \
		--go_out=. \
		--go-grpc_out=. \
		--go_opt=paths=source_relative \
		--go-grpc_opt=paths=source_relative \
		--proto_path=.

# testing

.PHONY: test
test: $(CONFIG_PATH)/model.conf $(CONFIG_PATH)/policy.csv
	go clean -testcache ./...
	go test -race ./...

put:
	curl -X POST localhost:8080 -d '{"record": {"value": "TGV0J3MgR28gIzEK"}}'
	curl -X POST localhost:8080 -d '{"record": {"value": "TGV0J3MgR28gIzIK"}}'
	curl -X POST localhost:8080 -d '{"record": {"value": "TGV0J3MgR28gIzMK"}}'

get:
	curl -X GET localhost:8080 -d '{"offset": 0}'
	curl -X GET localhost:8080 -d '{"offset": 1}'
	curl -X GET localhost:8080 -d '{"offset": 2}'

# deploy

image:
	docker build -t github.com/jonathanve/proglog:$(TAG) .

load:
	kind load docker-image github.com/jonathanve/proglog:$(TAG)

templates:
	helm template deploy/proglog

release:
	helm install proglog deploy/proglog

events:
	kubectl get event --field-selector involvedObject.name=proglog-0

port:
	kubectl port-forward pod/proglog-0 8400

uninstall:
	helm uninstall proglog

rmi:
	docker rmi github.com/jonathanve/proglog:$(TAG)
