module.exports = {
  apps: [
    {
      name: "such-gallery",
      script: "mix",
      args: "phx.server",
      cwd: "/root/such-gallery-elixir",
      env: {
        MIX_ENV: "prod",
        PHX_HOST: "such.gallery",
        PORT: "4000",
        PHX_SERVER: "true",
        SECRET_KEY_BASE: "wtDYk9uJhf400vM87Wh2VXq8CC6efBdEA/DQBVY7XKOVBeb7NQMZA9MNCX79kKh2",
        DATABASE_URL: "postgres://postgres:postgres@localhost/such_gallery_elixir_prod",
        PATH: "/root/.asdf/installs/rust/1.96.0/bin:/root/.asdf/shims:/root/.asdf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "1G",
    },
  ],
};
