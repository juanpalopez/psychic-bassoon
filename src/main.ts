import {createScene} from './render/scene';

const container = document.getElementById('app');
if (!container) {
  throw new Error('Missing #app container');
}

createScene(container);
