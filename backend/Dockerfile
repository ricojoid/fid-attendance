# Stage 1: Build binary
FROM golang:1.21-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main .

# Stage 2: Final minimal runner image
FROM alpine:latest

RUN apk add --no-cache tzdata ca-certificates
ENV TZ=Asia/Jakarta

WORKDIR /app

COPY --from=builder /app/main .

RUN mkdir -p /app/data /app/uploads

EXPOSE 8080

CMD ["./main"]
