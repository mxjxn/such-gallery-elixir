#!/bin/bash
cd /root/such-gallery-elixir
export MIX_ENV=prod
export PHX_HOST=such.gallery
export PORT=4003
export PHX_SERVER=true

# Source secrets from .env
export $(grep SUCH_GALLERY_SECRET_KEY_BASE /root/.hermes/.env | sed 's/SUCH_GALLERY_//')
export $(grep SUCH_GALLERY_DATABASE_URL /root/.hermes/.env | sed 's/SUCH_GALLERY_//')

# Add Rust to PATH for siwe NIF
export PATH="/root/.asdf/installs/rust/1.96.0/bin:$HOME/.asdf/shims:$HOME/.asdf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exec mix phx.server
