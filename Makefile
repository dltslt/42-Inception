# ------------------------------------------------------------------------------
# awesome service awareness feature
# ------------------------------------------------------------------------------
KNOWN_TARGETS := all build up down debug stop start sh clean fclean remove logs du duw ps psw
SERVICES := $(filter-out $(KNOWN_TARGETS),$(MAKECMDGOALS))
COMPOSEFILE := srcs/docker-compose.yml

# ------------------------------------------------------------------------------
# main targets
# ------------------------------------------------------------------------------

all: up

# creates containers from images and starts them
# --build enforces rebuild
# -d detached mode returns terminal
up: build
	@docker compose -f $(COMPOSEFILE) up -d $(SERVICES)

# build images from dockerfiles
# -f which compose file (because NOT in same dir)
build: 
	@docker compose -f $(COMPOSEFILE) build $(SERVICES)

# removes containers & networks but NOT volumes & images
down:
	@docker compose -f $(COMPOSEFILE) down $(if $(SERVICES),$(SERVICES),)

# ------------------------------------------------------------------------------
# feature targets
# ------------------------------------------------------------------------------

# build with full output
debug:
	@docker compose --progress=plain -f $(COMPOSEFILE) build $(SERVICES)
	@docker compose -f $(COMPOSEFILE) up -d $(SERVICES)

# stops all containers w/o removing anything; KEEPS containers, networks volumes
stop:
	@docker compose -f $(COMPOSEFILE) stop $(SERVICES)
# start all containers w/o rebuilding them
start:
	@docker compose -f $(COMPOSEFILE) start $(SERVICES)

# connect to a running server and start a shell
sh:
	@if [ "$(words $(SERVICES))" -ne 1 ]; then \
		echo "usage: make sh <service>"; \
		exit 1; \
	fi
	@docker compose -f $(COMPOSEFILE) exec -it $(SERVICES) sh

# ------------------------------------------------------------------------------
# service targets
# ------------------------------------------------------------------------------

# removes containers & networks & volumes but NOT images
clean:
	@docker compose -f $(COMPOSEFILE) down $(SERVICES) -v

# removes containers & networks & volumes & images & unused build cache
fclean:
	@docker compose -f $(COMPOSEFILE) down --rmi all -v
	@docker buildx prune --force || docker builder prune --force

# remove all data for a specific service & all dangling build cache
remove:
	@docker compose -f $(COMPOSEFILE) down $(SERVICES) --rmi all -v
	@docker buildx prune --force || docker builder prune --force
# concurrently read logs of the whole compose stack
logs:
	@docker compose -f $(COMPOSEFILE) logs -f

# show current docker disk usage
du:
	@docker system df
duw:
	@watch -n 5 'docker system df'

# show running services of current compose stack
ps:
	@docker compose -f $(COMPOSEFILE) ps
psw:
	@watch -n 1 'docker compose -f $(COMPOSEFILE) ps'

.PHONY: $(KNOWN_TARGETS)

# blackhole recipe to swallow all extra SERVICE make command goals
%:
	@:
