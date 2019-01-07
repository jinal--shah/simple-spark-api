# swarm stack
# vim: et sr sw=2 ts=2 smartindent:

>
> docker-compose file that creates stack
> or app A and B, dynamically load balanced by traefik
>

## provision on docker swarm

```bash
# ... create stack for current git ref (tag or else sha1)
STACK_ID=$(
    git describe --exact-match --tags 2>/dev/null \
    || git --no-pager rev-parse --short=8 --verify HEAD
)

docker stack deploy --compose-file docker-compose.yml $STACK_ID

# ... scale stack e.g. appA to 4 units - traefik will automatically scale
# and docker dns round-robin will send requests to each replica in turn.
docker service scale ${STACK_ID}_appA=4 ${STACK_ID}_appB=4

# ... interrogate stack with opsgang aws-ready container
docker run -it --rm --net ${STACK_ID}_stack --name ${STACK_ID}-ops \
    opsgang/aws_env:stable curl http://${STACK_ID}_traefik/message

# ... or interrogate the load-balancer ...
docker run -it --rm --net ${STACK_ID}_stack --name ${STACK_ID}-ops \
    opsgang/aws_env:stable /bin/bash -c "curl -sS http://${STACK_ID}_traefik:8080/api | jq -r ."

# ... destroy stack
docker stack rm $STACK_ID

```
