// vim: et sr sw=4 ts=4 smartindent:
/*
    ... using scripted pipeline instead of declarative, due to
    limitations of the docker-workflow with swarm.
*/
node {
    stage('checkout') {
        checkout scm
    }

    stage('build docker image') {
        docker.withServer("tcp://10.95.225.29:4243") {
            docker.image('jenkins-runner:stable').inside("-v /opt/cache/.m2:/root/.m2 -m 100m --cpus 0.5") {
                sh '''
                    /bin/bash ./build.sh
                '''
            }
        }
    }

    stage('run integration tests - provisions new stack') {
        docker.withServer("tcp://10.95.225.29:4243") {
            docker.image('jenkins-runner:stable').inside("-m 100m --cpus 0.5") {
                sh '''
                    /bin/bash ./integration_tests.sh
                '''
            }
        }
    }
}