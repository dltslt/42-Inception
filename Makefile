# ------------------------------------------------------------------------------
# awesome service awareness feature
# ------------------------------------------------------------------------------

COMPOSEFILE := srcs/docker-compose.yml
#VOLUME_DATA := /home/mweghofe/data/mariadb /home/mweghofe/data/wordpress
VOLUME_DATA := ./data/mariadb ./data/wordpress

KNOWN_TARGETS := all run build up down re\
				 debug stop start sh logs \
				 clean fclean remove du duw ps psw
KNOWN_SERVICES := nginx wordpress mariadb

REQUESTED_TARGETS := $(filter $(KNOWN_TARGETS),$(MAKECMDGOALS))
SERVICES := $(filter-out $(KNOWN_TARGETS),$(MAKECMDGOALS))
BAD_ARGUMENTS := $(filter-out $(KNOWN_SERVICES),$(SERVICES))

ifneq ($(strip $(BAD_ARGUMENTS)),)
$(info usage: make <target> [service])
$(info or     make [service])
$(error invalid argument(s): $(BAD_ARGUMENTS))
endif

# ------------------------------------------------------------------------------
# main targets
# ------------------------------------------------------------------------------

all: run

run: up

# creates containers from images and starts them
# --build enforces rebuild
# -d detached mode returns terminal
up: build
	@docker compose -f $(COMPOSEFILE) up -d $(SERVICES)

# build images from dockerfiles
# -f which compose file (because NOT in same dir)
build: 
	@mkdir -p $(VOLUME_DATA)
	@docker compose -f $(COMPOSEFILE) build $(SERVICES)

# removes containers & networks but NOT volumes & images
down:
	@docker compose -f $(COMPOSEFILE) down $(if $(SERVICES),$(SERVICES),)

re: remove run

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

# concurrently read logs of the whole compose stack
logs:
	@while :; do docker compose -f $(COMPOSEFILE) logs -f $(SERVICES); sleep 1; done

# ------------------------------------------------------------------------------
# service targets
# ------------------------------------------------------------------------------

# removes containers & networks & volumes but NOT images
clean:
	@docker compose -f $(COMPOSEFILE) down $(SERVICES) -v
	@if [ "$(words $(SERVICES))" -eq 0 ] || [ "$(words $(filter mariadb wordpress,$(SERVICES)))" -eq 2 ]; then \
		docker run --rm -v "$(CURDIR)/data:/data" busybox rm -rf $(VOLUME_DATA); \
	fi
	@docker buildx prune --force --filter "until=48h" || \
		docker builder prune --force --filter "until=48h"

# removes containers & networks & volumes & images & unused build cache
fclean:
	@docker compose -f $(COMPOSEFILE) down --rmi all -v
	@docker run --rm -v "$(CURDIR)/data:/data" busybox rm -rf $(VOLUME_DATA)
# 	@docker rmi busybox
	@docker buildx prune --force || docker builder prune --force

# remove all data for a specific service & all dangling build cache
remove:
	@docker compose -f $(COMPOSEFILE) down $(SERVICES) --rmi all -v
	@if [ "$(words $(SERVICES))" -eq 0 ] || [ "$(words $(filter mariadb wordpress,$(SERVICES)))" -eq 2 ]; then \
		docker run --rm -v "$(CURDIR)/data:/data" busybox rm -rf $(VOLUME_DATA); \
	fi
# 	@docker rmi busybox
	@docker buildx prune --force || docker builder prune --force

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

ifeq ($(words $(REQUESTED_TARGETS)), 0)
# create service recipes to support `make nginx` etc.
$(KNOWN_SERVICES): run
else
# blackhole recipe to swallow all extra SERVICE make command goals
%:
	@:
endif
