FROM golang:1.8-alpine as builder

RUN apk --update add git;
RUN go get -d github.com/optiopay/klar
RUN go build ./src/github.com/optiopay/klar

FROM uqlibrary/alpine

RUN apk add --no-cache ca-certificates
COPY --from=builder /go/klar /klar
ADD klar.sh /klar.sh

ENTRYPOINT ["/klar.sh"]
