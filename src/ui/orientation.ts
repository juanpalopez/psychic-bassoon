/**
 * A phone held upright: the game asks it to turn and pauses. Keep this in
 * step with the `@media` rule that shows `#rotate` in `hud.css`. Wider
 * windows (desktops, tablets) are never blocked.
 */
export const UPRIGHT_QUERY = '(orientation: portrait) and (max-width: 700px)';
