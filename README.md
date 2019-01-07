# Simple Java Spark App

_... code for java api, along with all assets required for build-test-deploy_


>
> A request to this app's endpoint /message 
> returns the response from a second app's /message endpoint.
>
> Exposes a /health endpoint as a basic health check.
>

* [... requires](#requires)
* [... tour of this repo](#the-tour)
* [... build](#build)
* [... integration tests](#integration-tests)
* [... run](#run)
    * [... env vars](#env-vars)
* [... find current version](#current-version)

## REQUIRES

Requires Java jre or jdk 1.8 (tested with openjdk)

Integration tests require that you have already built docker image
for 

## THE TOUR ...

```
.
├── .gitignore
├── README.md
│
├── .dockerignore         # assets specific to docker build and run
├── Dockerfile
├── docker-entrypoint.sh
│
├── build.sh             # maven and docker build script
├── integration-tests.sh # bootstraps integration tests against a docker-composed stack
│
├── cfg.sh               # vars consumed by scripts
├── libs.sh              # funcs consumed by scripts
│
├── integration-tests       # test code
│   └── integration_test.go # ... taking advantage of `go test`
│
├── provision-stack      # docker-compose assets used to spin up a load-balanced stack
│   ├── .env
│   ├── README.md
│   ├── docker-compose.yml
│   └── traefik.toml
│
├── pom.xml             # java assets for App A
└── src
    └── main
        ├── java
        │   └── app
        │       ├── ApplicationMain.java
        │       └── utils
        │           ├── EmbeddedJettyFactoryConstructor.java
        │           ├── EmbeddedJettyServerFactory.java
        │           ├── RequestLogFactory.java
        │           └── SparkUtils.java
        └── resources
            └── log4j.xml

```
---

## BUILD

Run `./build.sh`.

This runs maven to produce the artefact as well as
the docker-build.

### ... notes on build process

Built using `docker run` rather than `docker build`
to take advantage of volume mounts for m2 cache and
src.

Can take advantage of build parallelism as is coded threadsafe.

To build manually:

```bash
docker run -it --rm --name app-a-$(date +'%Y%m%d%H%M%S') \
    -v $HOME/projects/.m2:/root/.m2 \
    -v $PWD:/usr/src/mymaven `# $PWD is this git repo root` \
    -w /usr/src/mymaven maven:3-jdk-8-alpine \
        mvn -T 1C clean package
```

## INTEGRATION TESTS

Run `./integration_tests.sh`

This will docker-compose a stack on a docker-swarm node then launch
a dockerised golang test runner to test this version of the simple
java app.

See [provision-stack/README.md](provision-stack/README.md) for more
details about the ephemeral stack.

## RUN

Running jar listens on port 4567.

Obviously when you run the app in a container, you can map to whichever host port you like.

### ENV VARS

Set these configuration options before running the app:

* `$APP_B_URL`:
    * _optional_ - app B endpoint (full url).
    * default: http://appB/message
        for when app B is running as a container on the same
        docker network (and therefore same host). e.g. locally

>
> e.g. you might set this to something unique to run multiple stacks
> of app A and app B on the same host (even on the same docker network).
>
 
```bash
# connect app A v.1.0.0 to app B v0.1.0
export APP_B_URL=http://appB-0.1.0:5000/message

# ... run appB
docker run -d --net apps --name appB \
    -p 5000:5000 \
        simple-node-api:1.0.0

# ... run appA
docker run -d --net apps --name appA \
    -p 4567:4567 \
    -e APP_B_URL \
    -v $PWD/target:/target \
        openjdk:8-jdk-alpine java -jar /target/simple-spark-api-1.0.0-jar-with-dependencies.jar
```

```bash
# ... run jar
java -jar target/simple-spark-api-1.0.0-jar-with-dependencies.jar

# ... run container
```

## CURRENT VERSION

Quick, scripted way to get current version of app from pom.xml:

```bash
docker run -it --rm --name app-a-$(date +'%Y%m%d%H%M%S') \
    -v $HOME/.m2:/root/.m2 \
    -v $PWD:/usr/src/mymaven `# $PWD is this git repo root` \
    -w /usr/src/mymaven maven:3-jdk-8-alpine \
        mvn -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec
```
