FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN apk update && apk upgrade --no-cache && go mod download
COPY . .
RUN go build -o main .

FROM alpine:latest
WORKDIR /app
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
