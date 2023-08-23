# vmp-http-spec: The virtual streaming processor HTTP API specification

This subproject specifies the HTTP API interface for the VMP.
It is intended to be used as a way to monitor and control the VMP remotely.

The API is specified using the OpenAPI 3.0 specification, and can be build
into a single OpenAPI specification (either YML or JSON) using Redocly CLI.

## Building
### Prerequisites
- Latest NodeJS 
- [Redocly CLI](https://github.com/Redocly/redocly-cli) (Install using `npm install -g @redocly/openapi-cli`)

A combined OpenAPI specification can be bundled using the following command:
```sh
openapi bundle -o vmp-http-api.json index.yml
```
