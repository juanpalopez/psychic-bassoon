import {GRID} from './content';
import {createMapView} from './render/map';
import {createScene} from './render/scene';
import {generateMap} from './sim';

const container = document.getElementById('app');
if (!container) {
  throw new Error('Missing #app container');
}

// Until the HUD and loop land, show a fixed map so the board can be checked.
const handle = createScene(container, GRID);
handle.scene.add(createMapView(generateMap(42)).group);
