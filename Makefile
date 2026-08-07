# Narra development and release entry points.
# Keep implementation details in tools/ scripts so commands behave consistently
# in local terminals, CI jobs, and direct PowerShell use.

.DEFAULT_GOAL := help

POWERSHELL ?= powershell.exe
PYTHON ?= py
PYTHON3 ?= python3
GO ?= go
GODOT ?= godot
BASH ?= bash
GODOT_VERSION ?= 4.7.1.stable
VERSION ?=
PACKAGE_DIR ?= dist/narra-windows-x86_64

PS_FILE := $(POWERSHELL) -NoLogo -NoProfile -ExecutionPolicy Bypass -File
VERSION_ARG := $(if $(strip $(VERSION)),-Version "$(VERSION)",)

.PHONY: help doctor fmt test test-go test-godot test-logging vet verify \
	run-cli run-server run-godot record-gameplay \
	build build-server templates-windows templates-macos templates-linux package-windows package-windows-fast \
	package-macos package-macos-fast package-linux package-linux-fast release-windows smoke-windows clean clean-package clean-server

help:
	@echo Narra development commands
	@echo.
	@echo   make doctor                 Check required tools and export templates
	@echo   make fmt                    Format Go source files
	@echo   make test                   Run Go and Godot tests
	@echo   make test-go                Run the Go test suite
	@echo   make test-godot             Run Godot integration tests
	@echo   make test-logging           Test logging failure and rotation paths
	@echo   make vet                    Run go vet
	@echo   make verify                 Run formatting, tests, vet, and Godot checks
	@echo.
	@echo   make run-cli                Start the terminal game
	@echo   make run-server             Start the local rules service
	@echo   make run-godot              Build the service and start the Godot game
	@echo   make record-gameplay        Record the automated gameplay demo
	@echo.
	@echo   make build-server           Build bin/narra-server.exe
	@echo   make templates-windows      Install matching Windows export templates
	@echo   make templates-macos        Install matching macOS export template
	@echo   make templates-linux        Install matching Linux x86_64 export templates
	@echo   make package-windows        Test and create the Windows portable ZIP
	@echo   make package-windows-fast   Package without rerunning Go tests
	@echo   make package-macos          On macOS, test and create an unsigned Universal ZIP
	@echo   make package-macos-fast     On macOS, package without rerunning Go tests
	@echo   make package-linux          On Linux, test and create an x86_64 tarball
	@echo   make package-linux-fast     On Linux, package without rerunning Go tests
	@echo   make release-windows        Run all checks and create the release ZIP
	@echo   make smoke-windows          Smoke-test an existing Windows package
	@echo.
	@echo   make clean                  Remove dist and bin build artifacts
	@echo   make clean-package          Remove only dist artifacts
	@echo   make clean-server           Remove only bin artifacts
	@echo.
	@echo Variables: VERSION=0.1.0 GODOT_VERSION=4.7.1.stable

doctor:
	$(PS_FILE) tools/doctor.ps1

fmt:
	$(GO) fmt ./...

test: test-go test-godot

test-go:
	$(GO) test ./...

test-godot:
	$(PS_FILE) tools/verify-godot.ps1

test-logging:
	$(GO) test ./internal/logfile ./internal/diagnosticlog ./internal/crashreport ./cmd/server ./internal/server
	$(PS_FILE) tools/verify-server-diagnostics.ps1

vet:
	$(GO) vet ./...

verify:
	$(PS_FILE) tools/verify.ps1
	$(PS_FILE) tools/verify-server-diagnostics.ps1
	$(PS_FILE) tools/verify-godot.ps1

run-cli:
	$(GO) run ./cmd/play

run-server:
	$(GO) run ./cmd/server

run-godot:
	$(PS_FILE) tools/run-godot.ps1

record-gameplay:
	$(PS_FILE) tools/record-gameplay.ps1

build: build-server

build-server:
	$(POWERSHELL) -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Force bin | Out-Null"
	$(GO) build -trimpath -ldflags="-s -w" -o bin/narra-server.exe ./cmd/server

templates-windows:
	$(PYTHON) tools/install-godot-templates.py --platform windows --version $(GODOT_VERSION)

templates-macos:
	$(PYTHON) tools/install-godot-templates.py --platform macos --version $(GODOT_VERSION)

templates-linux:
	$(PYTHON3) tools/install-godot-templates.py --platform linux --version $(GODOT_VERSION)

package-windows:
	$(PS_FILE) tools/build-windows.ps1 $(VERSION_ARG)

package-windows-fast:
	$(PS_FILE) tools/build-windows.ps1 -SkipTests $(VERSION_ARG)

package-macos:
	$(BASH) tools/build-macos.sh "$(if $(strip $(VERSION)),$(VERSION),dev)"

package-macos-fast:
	SKIP_TESTS=1 $(BASH) tools/build-macos.sh "$(if $(strip $(VERSION)),$(VERSION),dev)"

package-linux:
	$(BASH) tools/build-linux.sh "$(if $(strip $(VERSION)),$(VERSION),dev)"

package-linux-fast:
	SKIP_TESTS=1 $(BASH) tools/build-linux.sh "$(if $(strip $(VERSION)),$(VERSION),dev)"

release-windows:
	$(MAKE) verify
	$(MAKE) package-windows-fast VERSION="$(VERSION)"

smoke-windows:
	$(PS_FILE) tools/smoke-test-windows.ps1 -PackageDirectory "$(PACKAGE_DIR)"

clean:
	$(PS_FILE) tools/clean.ps1 -Scope all

clean-package:
	$(PS_FILE) tools/clean.ps1 -Scope package

clean-server:
	$(PS_FILE) tools/clean.ps1 -Scope server
