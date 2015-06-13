import { _ } from 'azk';
import { UIProxy } from 'azk/cli/ui';
import { example_system } from 'azk/generator/rules';

export class Suggestion extends UIProxy {
  constructor(...args) {
    super(...args);

    // Readable name for this suggestion
    this.name = 'php';

    // Which rules they suggestion is valid
    this.ruleNamesList = ['php'];

    // Initial Azkfile.js suggestion
    this.suggestion = _.extend({}, example_system, {
      __type  : 'php',
      image   : { docker: 'azukiapp/php-fpm' },
      http    : true,
      ports: {
        http: "80/tcp",
      },
      command: null,
      scalable: { default: 1 },
      mounts  : {
        '/azk/#{manifest.dir}': {type: 'path', value: '.'}
      },
      envs: {
        // set instances variables
        APP_DIR: '/azk/#{manifest.dir}',
      },
      docker_extra: {
        start: { Privileged: true },
      }
    });
  }

  suggest() {
    return this.suggestion;
  }
}
