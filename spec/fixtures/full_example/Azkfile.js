/**
 * http://azk.io file
 */

// Global image to reuse
addImage('base', { repository: "cevich/empty_base_image" }); // tag: latest
addImage('base:0.0.1', "cevich/empty_base_image:latest");    // Alias
addImage('base:0.0.2', { Dockerfile: "." });                 // From Dockerfile
addImage('base:0.0.3', { from: "base:0.0.1", steps: [
  ["add", "./bin/script", "/script"],
  ["run", "chmod +x /script"],
]}); // Inline build

systems({
  front: {
    depends: [ "api" ],
    image: "base",
    // Enable balancer over de instances
    balancer: {
      hostname: "myapp_<%= system.name %>",
      alias: [
        "front.<%= azk.default_domain %>"
      ],
    },
    // Run dir app
    workdir: "/azk/<%= system.name %>",
    // Enable sync current project folder to '/app' in containers
    sync_files: {
      ".": "/azk/<%= system.name %>",
    },
    // Active a persistent data folder in '/azk/_data_' in containers
    persistent_dir: true,
    command: "rails -s mongrel",
    envs: {
      RAILS_VERSION: "3.2.0"
    },
  },

  api: {
    depends: [ "db_slave" ],
    image: {
      // Autoname: [project_id]/[projec_folder]/api
      // Don't use direct docker image, build one from a Dockerfile
      Dockerfile: "./api"
    },
    balancer: {
      hostname: "myapp_<%= system.name %>",
    },
    volumes: {
      ".": "/app"
    },
    command: "rackup -S thin -G /app/config.ru",
    envs: {},
  },

  worker: {
    image: "base",
    auto_start: false,
    depends: [ "db_slave", "api" ],
    build: { "path": "../worker" }, // Find ../worker/Dockerfile to build
    volumes: {
      "../worker": "/worker"
    },
    command: "python worker.py",
  },

  db_master: {
    image: "orchardup/postgresql",
  },

  db_slave: {
    image: "orchardup/postgresql",
    depends: [ "db_master" ]
  }
});

system("db", {
  image: "orchardup/redis"
});

setDefault("front");
//registerBin("rails-c", ["exec", "-i", "/bin/bash", "-c", "rails c"]);

/*
$ azk run
  - pulls images:
    - orchardup/postgresql
    - azukiapp/rails
    - binaryphile/ruby:2.0.0-p247
  - build images:
    - api from binaryphile/ruby:2.0.0-p247
  - starting:
    - db_master => docker run -d -n db_master_1 orchardup/postgresql
      - 435436:6379
    - db_slave  => docker run -d -n db_slave_1 -link db_master_1:db_master orchardup/postgresql
      - 435437:6379
    - api       => docker run -d -n api_1 -link db_slave_1:db_slave api
      - 435438:80
      - balancer add host: api.dev.azk.io
    - 3 x front => docker run -d -n front_1 -link db_slave_1:db_slave -link api_1:api azukiapp/rails
      - 435438:80
      - 435439:80
      - 435440:80
      - balancer add host: front.dev.azk.io

$ azk start -s worker
  - starting:
    - worker => docker run -d -n worker_1 -link api_1:api -link db_slave_1:db_slave azukiapp/rails

$ azk status -s front
  # error: front require started db

$ azk exec -i /bin/bash # use default
$ azk exec -i -s api /bin/bash
$ azk exec -b /bin/bash # sync back active

$ azk exec -i # use default

  azk.initConfig({
    "api": {
    },

    "front": {
    }

    "db": {
    }
  })

  azk.registerAlias("web", ["api", "front"])

  // $ azk start -s api,front
  // $ azk exec -s api /bin/bash
  // $ azk console
  //
  azk.registerBin("rails-c", "exec", "-s api", "-i", "/bin/bash", "-c", "rails c")

  // $azk rails-c
  // $azk generator bins
  //
  // ./bin/rails-c
*/
