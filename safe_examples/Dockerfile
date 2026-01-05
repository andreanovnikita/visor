FROM alpine:3.18
RUN apk add --no-cache python3
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --chown=app:app . /app
USER app
CMD ["python3", "app.py"]
