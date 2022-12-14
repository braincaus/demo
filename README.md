# DEMO

This project was created to demostrate a Django project integrated with Docker and with another tools like diferentes DBs, an event manager (RabbitMQ) with Celery.

To create the project

    django-admin startproject demo

Create requirements.txt, Dockerfile and docker-compose.yml

    touch requirements.txt
    touch Dockerfile
    touch docker-compose.yml

On requirements.txt:
    
    Django
    psycopg2

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

To execute migrations:

    docker-compose exec web python manage.py migrate
    docker-compose exec web python manage.py createsuperuser

Test on [http://localhost:8000](http://localhost:8000)

In order to manage events we are going to use Celery with RabbitMQ, so, add on docker-compose-yml:

    rabbitmq:
      image: rabbitmq:management-alpine
      environment:
        - RABBITMQ_DEFAULT_VHOST=demo_vhost
        - RABBITMQ_DEFAULT_USER=demo
        - RABBITMQ_DEFAULT_PASS=demo
      ports:
        - "5672:5672"
        - '15672:15672'

    web:
      ...
      environment:
        ...
        - RABBITMQ_DEFAULT_VHOST=demo_vhost
        - RABBITMQ_DEFAULT_USER=demo
        - RABBITMQ_DEFAULT_PASS=demo
      depends_on:
        ...
        - rabbitmq

On requirements.py add:

    celery
    flower

Create a new file celery.py at same folder where settings.py is:

    touch celery.py

On this new file:

    import os
    
    from celery import Celery
    
    # set the default Django settings module for the 'celery' program.
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'demo.settings')
    
    app = Celery('demo', broker='amqp://demo:demo@rabbitmq:5672/demo_vhost')
    
    # Using a string here means the worker doesn't have to serialize
    # the configuration object to child processes.
    # - namespace='CELERY' means all celery-related configuration keys
    #   should have a `CELERY_` prefix.
    app.config_from_object('django.conf:settings', namespace='CELERY')
    
    # Load task modules from all registered Django app configs.
    app.autodiscover_tasks()
    
    
    @app.task(bind=True)
    def debug_task(self):
        print('Request: {0!r}'.format(self.request))
        return True

On _\__init___.py

    from .celery import app as celery_app
    
    __all__ = ('celery_app',)

In order to run our worker and beat (scheduled tasks), create a new services on docker-compose.yml:

      worker:
        image: demo-web
        volumes:
          - .:/code
        command: python -m celery -A demo worker -l info
        environment:
          - POSTGRES_HOST=db
          - POSTGRES_NAME=demo
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=postgres
          - RABBITMQ_DEFAULT_VHOST=demo_vhost
          - RABBITMQ_DEFAULT_USER=demo
          - RABBITMQ_DEFAULT_PASS=demo
        depends_on:
          - web
      beat:
        image: demo-web
        volumes:
          - .:/code
        command: python -m celery -A demo beat -l info
        environment:
          - POSTGRES_HOST=db
          - POSTGRES_NAME=demo
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=postgres
          - RABBITMQ_DEFAULT_VHOST=demo_vhost
          - RABBITMQ_DEFAULT_USER=demo
          - RABBITMQ_DEFAULT_PASS=demo
        depends_on:
          - web

In order to monitor our worker, create a new service:

      flower:
        image: demo-web
        volumes:
          - .:/code
        command: python -m celery -A demo flower
        ports:
          - "5555:5555"
        environment:
          - POSTGRES_HOST=db
          - POSTGRES_NAME=demo
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=postgres
          - RABBITMQ_DEFAULT_VHOST=demo_vhost
          - RABBITMQ_DEFAULT_USER=demo
          - RABBITMQ_DEFAULT_PASS=demo
        depends_on:
          - web
