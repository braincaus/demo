# syntax=docker/dockerfile:1
FROM python:3-alpine
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /code
COPY . /code/
RUN apk add build-base postgresql-dev && pip install -r requirements.txt
