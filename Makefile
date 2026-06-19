# ------------------------------------------------------------------------------
# awesome service awareness feature
# ------------------------------------------------------------------------------
KNOWN_TARGETS := all build up down debug stop start clean fclean logs du duw ps psw
SERVICES := $(filter-out $(KNOWN_TARGETS),$(MAKECMDGOALS))

# ------------------------------------------------------------------------------
# main targets
# ------------------------------------------------------------------------------

all: up

# build images from dockerfiles
# -f which compose file (because NOT in same dir)
build: 
	@docker compose -f srcs/docker-compose.yml build $(SERVICES)

# creates containers from images and starts them
# --build enforces rebuild
# -d detached mode returns terminal
up: build
	@docker compose -f srcs/docker-compose.yml up -d $(SERVICES)

# removes containers & networks but NOT volumes & images
down:
	@docker compose -f srcs/docker-compose.yml down $(if $(SERVICES),$(SERVICES),)

# ------------------------------------------------------------------------------
# feature targets
# ------------------------------------------------------------------------------

# build with full output
debug:
	@docker compose --progress=plain -f srcs/docker-compose.yml build $(SERVICES)
	@docker compose -f srcs/docker-compose.yml up -d $(SERVICES)

# stops all containers w/o removing anything; KEEPS containers, networks volumes
stop:
	@docker compose -f srcs/docker-compose.yml stop $(SERVICES)
# start all containers w/o rebuilding them
start:
	@docker compose -f srcs/docker-compose.yml start $(SERVICES)

# ------------------------------------------------------------------------------
# service targets
# ------------------------------------------------------------------------------

# removes containers & networks & volumes but NOT images
clean:
	@docker compose -f srcs/docker-compose.yml down -v
# removes containers & networks & volumes & images & unused build cache
fclean:
	@docker compose -f srcs/docker-compose.yml down --rmi all -v
	@docker buildx prune --force || docker builder prune --force

# concurrently read logs of the whole compose stack
logs:
	@docker compose -f srcs/docker-compose.yml logs -f

# show current docker disk usage
du:
	@docker system df
duw:
	@watch -n 5 'docker system df'

# show running services of current compose stack
ps:
	@docker compose -f srcs/docker-compose.yml ps
psw:
	@watch -n 1 'docker compose -f srcs/docker-compose.yml ps'

.PHONY: $(KNOWN_TARGETS)

# blackhole recipe to swallow all extra SERVICE make command goals
%:
	@:
