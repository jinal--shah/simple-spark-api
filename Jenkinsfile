// vim: et sr sw=4 ts=4 smartindent:
/*
    ... using scripted pipeline instead of declarative, due to
    limitations of the docker-workflow with swarm.
*/
node {
    stage('checkout') {
        checkout scm
    }

    try {
        stage('build docker image') {
            docker.withServer("${env.DOCKER_HOST}") {
                docker.image('jenkins-runner:stable').inside("-v /opt/cache/.m2:/root/.m2 -m 100m --cpus 0.5") {
                    sh '''
                        /bin/bash ./build.sh
                    '''
                }
            }
        }

        stage('run integration tests - provisions new stack') {
            docker.withServer("${env.DOCKER_HOST}") {
                docker.image('jenkins-runner:stable').inside("-m 100m --cpus 0.5") {
                    sh '''
                        /bin/bash ./integration-tests.sh
                    '''
                }
            }

        }
    } finally {
        junit 'integration-tests/**/*.xml' // this will throw any error in the try {}
        cleanWs()
    }
}
