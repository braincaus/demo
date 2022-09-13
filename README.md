# DEMO

This project was created to demostrate a Django project integrated with Docker and with another tools like diferentes DBs, an event manager (RabbitMQ) with Celery.

To create the project

    django-admin startproject demo

Create Dockerfile and docker-compose.yml

    touch Dockerfile
    touch docker-compose.yml

On Dockerfile:

    FROM python:3-alpine
    ENV PYTHONDONTWRITEBYTECODE=1
    ENV PYTHONUNBUFFERED=1
    WORKDIR /code
    COPY . /code/
    RUN apk add build-base postgresql-dev && pip install -r requirements.txt

On docker-compose.yml:

    version: "3.9"

    services:
      db:
        image: postgres
        volumes:
          - ./data/db:/var/lib/postgresql/data
        ports:
          - "5432:5432"
        environment:
          - POSTGRES_DB=demo
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=postgres
      web:
        build: .
        command: python manage.py runserver 0.0.0.0:8000
        volumes:
          - .:/code
        ports:
          - "8000:8000"
        environment:
          - POSTGRES_HOST=db
          - POSTGRES_NAME=demo
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=postgres
        depends_on:
          - db

On seetings.py change:

    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.environ.get('POSTGRES_NAME'),
            'USER': os.environ.get('POSTGRES_USER'),
            'PASSWORD': os.environ.get('POSTGRES_PASSWORD'),
            'HOST': os.environ.get('POSTGRES_HOST'),
            'PORT': 5432,
        }
    }

