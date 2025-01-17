#!/bin/bash
# The script does automatic checking on a Go package and its sub-packages, including:
# 1. gofmt         (http://golang.org/cmd/gofmt/)
# 2. go vet        (http://golang.org/cmd/vet)
# 3. gosimple      (https://github.com/dominikh/go-simple)
# 4. unconvert     (https://github.com/mdempsky/unconvert)
# 5. ineffassign   (https://github.com/gordonklaus/ineffassign)
# 6. unused        (https://github.com/dominikh/go-tools)
# 7. test coverage (http://blog.golang.org/cover)
#
set -ex

# run tests
env GORACE="halt_on_error=1" go test ./...

# golangci-lint (github.com/golangci/golangci-lint) is used to run each each
# static checker.

# check linters
golangci-lint run

# check client protobuf linters
(cd clientrpc && protolint lint .)

# To submit the test coverage result to coveralls.io,
# use goveralls (https://github.com/mattn/goveralls)
# goveralls -coverprofile=profile.cov -service=travis-ci
