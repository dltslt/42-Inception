all: up

# -f what compose file (because NOT in same dir)
build: 
	@docker compose -f srcs/docker-compose.yml build

# creates containers from images and starts them
# --build enforces rebuild
# -d detached mode returns terminal
up: build
	@docker compose -f srcs/docker-compose.yml up -d
# removes containers & networks but NOT volumes & images
down:
	@docker compose -f srcs/docker-compose.yml down

.PHONY: all build up down