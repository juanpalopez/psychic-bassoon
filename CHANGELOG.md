# Changelog

## [0.1.0-alpha.9](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.8...v0.1.0-alpha.9) (2026-10-24)


### Features

* **sim:** add a debug flag to play the layout valley ([#514](https://github.com/juanpalopez/psychic-bassoon/issues/514)) ([3a2933f](https://github.com/juanpalopez/psychic-bassoon/commit/3a2933ff6ed51b8fe3664a610b9964baabd6b4d5)), closes [#513](https://github.com/juanpalopez/psychic-bassoon/issues/513)
* **sim:** add the jog road segment template ([#494](https://github.com/juanpalopez/psychic-bassoon/issues/494)) ([0c6ec4b](https://github.com/juanpalopez/psychic-bassoon/commit/0c6ec4b16afad78c4f7f7707e873e44eec617332)), closes [#481](https://github.com/juanpalopez/psychic-bassoon/issues/481)
* **sim:** grow the layout valley to 40 by 24 ([#485](https://github.com/juanpalopez/psychic-bassoon/issues/485)) ([8e99d38](https://github.com/juanpalopez/psychic-bassoon/commit/8e99d38d982028011c522c86313291f3cfdba488)), closes [#480](https://github.com/juanpalopez/psychic-bassoon/issues/480)
* **sim:** lay two lanes out through the meadow and the crossing ([#510](https://github.com/juanpalopez/psychic-bassoon/issues/510)) ([3f2520a](https://github.com/juanpalopez/psychic-bassoon/commit/3f2520a705b39f6507520a6c8c30c3293f889139)), closes [#481](https://github.com/juanpalopez/psychic-bassoon/issues/481)
* **sim:** mark every cell the layout valley's road bed touches as road ([#490](https://github.com/juanpalopez/psychic-bassoon/issues/490)) ([cfab674](https://github.com/juanpalopez/psychic-bassoon/commit/cfab67472180d39d689eb22b4764426e093d35f8)), closes [#469](https://github.com/juanpalopez/psychic-bassoon/issues/469)
* **sim:** measure ground range to the road band's edge behind a reach band ([#499](https://github.com/juanpalopez/psychic-bassoon/issues/499)) ([395ccdb](https://github.com/juanpalopez/psychic-bassoon/commit/395ccdbda6599eb80483baa561fc3ea6df3e14d9)), closes [#446](https://github.com/juanpalopez/psychic-bassoon/issues/446)
* **sim:** measure the hero, the bot and range rings to the road band's edge ([#506](https://github.com/juanpalopez/psychic-bassoon/issues/506)) ([726b06a](https://github.com/juanpalopez/psychic-bassoon/commit/726b06a48ea6ed6b178dc878ba50cbc1434ceed8)), closes [#446](https://github.com/juanpalopez/psychic-bassoon/issues/446)
* **sim:** measure time under fire to the road band's edge ([#501](https://github.com/juanpalopez/psychic-bassoon/issues/501)) ([be48aa9](https://github.com/juanpalopez/psychic-bassoon/commit/be48aa93b2150561b172d426fff3156d25efa2d0)), closes [#446](https://github.com/juanpalopez/psychic-bassoon/issues/446)
* **sim:** pick a branch for each foe on a forked map ([#493](https://github.com/juanpalopez/psychic-bassoon/issues/493)) ([0b8a7a8](https://github.com/juanpalopez/psychic-bassoon/commit/0b8a7a88b2d5fe69531f65c4cab368f64ba5765c)), closes [#481](https://github.com/juanpalopez/psychic-bassoon/issues/481)
* **sim:** post guards on the branch of their bridge ([#500](https://github.com/juanpalopez/psychic-bassoon/issues/500)) ([ce13736](https://github.com/juanpalopez/psychic-bassoon/commit/ce137362d67345dce3b5cff3a71e72c48c6e687a)), closes [#481](https://github.com/juanpalopez/psychic-bassoon/issues/481)


### Bug Fixes

* **build:** stop headless godot crashing in threaded imports ([#507](https://github.com/juanpalopez/psychic-bassoon/issues/507)) ([3a56b6f](https://github.com/juanpalopez/psychic-bassoon/commit/3a56b6f6524dc58bf6bd052e4b86cba84f5aa06e)), closes [#504](https://github.com/juanpalopez/psychic-bassoon/issues/504)

## [0.1.0-alpha.8](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.7...v0.1.0-alpha.8) (2026-10-23)


### Features

* **sim:** add the hook and u_turn road templates ([#471](https://github.com/juanpalopez/psychic-bassoon/issues/471)) ([baf9afd](https://github.com/juanpalopez/psychic-bassoon/commit/baf9afd5f0176021c300b8775d0b741f20c9e549)), closes [#460](https://github.com/juanpalopez/psychic-bassoon/issues/460)
* **sim:** lay the composed road in every region of the layout valley ([#457](https://github.com/juanpalopez/psychic-bassoon/issues/457)) ([af863d6](https://github.com/juanpalopez/psychic-bassoon/commit/af863d608d3626b2ca19ce59865753c26fe5e4ee))
* **sim:** let the knight hold and fight foes ([#467](https://github.com/juanpalopez/psychic-bassoon/issues/467)) ([03eb1f7](https://github.com/juanpalopez/psychic-bassoon/commit/03eb1f7188228ded9f5d91b207e95406d27cd01d)), closes [#451](https://github.com/juanpalopez/psychic-bassoon/issues/451)


### Bug Fixes

* **render:** draw one bridge over each road crossing of the river ([#466](https://github.com/juanpalopez/psychic-bassoon/issues/466)) ([9cda3df](https://github.com/juanpalopez/psychic-bassoon/commit/9cda3dfa7a96766ccb269a9d7c81f8c3c88f62b7)), closes [#461](https://github.com/juanpalopez/psychic-bassoon/issues/461)
* **sim:** spawn an east-edge road past that edge and share the routes ([#465](https://github.com/juanpalopez/psychic-bassoon/issues/465)) ([9ce6864](https://github.com/juanpalopez/psychic-bassoon/commit/9ce686497c75672cfcc942c1b43c1fc8b0002873)), closes [#461](https://github.com/juanpalopez/psychic-bassoon/issues/461)
* **sim:** start the second road on the top edge of the layout valley ([#463](https://github.com/juanpalopez/psychic-bassoon/issues/463)) ([cbd345e](https://github.com/juanpalopez/psychic-bassoon/commit/cbd345eff088cb103023e11e3a84ea630df63948)), closes [#462](https://github.com/juanpalopez/psychic-bassoon/issues/462)

## [0.1.0-alpha.7](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.6...v0.1.0-alpha.7) (2026-10-23)


### Features

* **sim:** give the hero a deterministic cell path on any board ([#454](https://github.com/juanpalopez/psychic-bassoon/issues/454)) ([b36d6fc](https://github.com/juanpalopez/psychic-bassoon/commit/b36d6fc0d828216166b57aa62fc0f306c24c0db4)), closes [#449](https://github.com/juanpalopez/psychic-bassoon/issues/449)
* **sim:** make the layout valley's road a wide band foes walk abreast ([#441](https://github.com/juanpalopez/psychic-bassoon/issues/441)) ([01f1dd3](https://github.com/juanpalopez/psychic-bassoon/commit/01f1dd3585cf1866fd37303280c70f8ae4e904f7))
* **sim:** start the game board with the knight and add a move command ([#455](https://github.com/juanpalopez/psychic-bassoon/issues/455)) ([e66d1d1](https://github.com/juanpalopez/psychic-bassoon/commit/e66d1d12f8180ce248ddfe78f4e14267bb2f8a9f))


### Bug Fixes

* **build:** start the iOS export from an empty folder ([#447](https://github.com/juanpalopez/psychic-bassoon/issues/447)) ([3d9b7bf](https://github.com/juanpalopez/psychic-bassoon/commit/3d9b7bfcadc076bb2dad4585240518ea3e13e371))

## [0.1.0-alpha.6](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.5...v0.1.0-alpha.6) (2026-10-22)


### Features

* **sim:** add the road segment library with five tested templates ([#436](https://github.com/juanpalopez/psychic-bassoon/issues/436)) ([1f811b0](https://github.com/juanpalopez/psychic-bassoon/commit/1f811b052352c63a60792b7d983821bfc17bc74c))
* **sim:** compose each region's road from segments in place of spines ([#439](https://github.com/juanpalopez/psychic-bassoon/issues/439)) ([b4ee466](https://github.com/juanpalopez/psychic-bassoon/commit/b4ee46604f649fd78beeb6331ea6873c6d515814))
* **sim:** fit a road template between two gates of a region ([#438](https://github.com/juanpalopez/psychic-bassoon/issues/438)) ([d50cef4](https://github.com/juanpalopez/psychic-bassoon/commit/d50cef4ebd71553d44c773b93c69b0c226590073))


### Bug Fixes

* **sim:** sweep all 300 seeds and drop dead crossing rules ([#442](https://github.com/juanpalopez/psychic-bassoon/issues/442)) ([23f14e2](https://github.com/juanpalopez/psychic-bassoon/commit/23f14e2420b072e2916d5fdb40c3b31f7b3ec230)), closes [#433](https://github.com/juanpalopez/psychic-bassoon/issues/433)

## [0.1.0-alpha.5](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.4...v0.1.0-alpha.5) (2026-10-21)


### Features

* **sim:** add the lane rule for valley roads ([#423](https://github.com/juanpalopez/psychic-bassoon/issues/423)) ([96c122e](https://github.com/juanpalopez/psychic-bassoon/commit/96c122e3f5a624b81e035bed300b9763e3476d22))
* **sim:** build roads from a spline and walk the curve ([#414](https://github.com/juanpalopez/psychic-bassoon/issues/414)) ([8faf66e](https://github.com/juanpalopez/psychic-bassoon/commit/8faf66ec82b49494694acd5d03bb471eae507d33))
* **sim:** build the ridge and meadow regions on spline roads ([#424](https://github.com/juanpalopez/psychic-bassoon/issues/424)) ([51184f0](https://github.com/juanpalopez/psychic-bassoon/commit/51184f0a21df12e990826004bc6194d21bfda709))
* **sim:** cross the winding river on a bridge in the Crossing region ([#419](https://github.com/juanpalopez/psychic-bassoon/issues/419)) ([6d66adc](https://github.com/juanpalopez/psychic-bassoon/commit/6d66adcd55a28fe3fb49932912db4fb8a4938798)), closes [#409](https://github.com/juanpalopez/psychic-bassoon/issues/409)
* **sim:** give each layout region its own section class ([#418](https://github.com/juanpalopez/psychic-bassoon/issues/418)) ([7e31f13](https://github.com/juanpalopez/psychic-bassoon/commit/7e31f13ceaa13e7a907b75ffe0c47ca2fb919cac))
* **sim:** lay each region's road out as one wide bend ([#426](https://github.com/juanpalopez/psychic-bassoon/issues/426)) ([69f31e6](https://github.com/juanpalopez/psychic-bassoon/commit/69f31e606b12564c1e3bfd25a217703ddd2f9b3d))
* **sim:** lay the valley out as 2D regions with a river spline ([#416](https://github.com/juanpalopez/psychic-bassoon/issues/416)) ([80fb604](https://github.com/juanpalopez/psychic-bassoon/commit/80fb6049a488e697c23a574e5191155891446c72))
* **sim:** outer march s-bend and heartkeep approach on regions ([#420](https://github.com/juanpalopez/psychic-bassoon/issues/420)) ([ccf5fd5](https://github.com/juanpalopez/psychic-bassoon/commit/ccf5fd5a3a1ecdeb89af21b95bc47456a673adf8))
* **sim:** ruins and a diagonal spline feeder in the Ancient Fold ([#421](https://github.com/juanpalopez/psychic-bassoon/issues/421)) ([3a0187a](https://github.com/juanpalopez/psychic-bassoon/commit/3a0187a675c18cac90b3f243bf2ad6b061857057))
* **sim:** stitch the 2D layout with stand-in sections and a print tool ([#417](https://github.com/juanpalopez/psychic-bassoon/issues/417)) ([f4b951e](https://github.com/juanpalopez/psychic-bassoon/commit/f4b951e45d15a8e2032ffae9a6ddf51005ec3efe))
* **sim:** sweep each region's road on diagonals and dump the valley ([#427](https://github.com/juanpalopez/psychic-bassoon/issues/427)) ([caf17ed](https://github.com/juanpalopez/psychic-bassoon/commit/caf17ed69a765e32997b417ced7bff66183c2620))


### Bug Fixes

* **sim:** stop uneven waypoints from looping the road spline ([#422](https://github.com/juanpalopez/psychic-bassoon/issues/422)) ([548f28c](https://github.com/juanpalopez/psychic-bassoon/commit/548f28c89722fc1e9537cc774a279b9f57e5b341)), closes [#404](https://github.com/juanpalopez/psychic-bassoon/issues/404)

## [0.1.0-alpha.4](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.3...v0.1.0-alpha.4) (2026-10-21)


### Features

* **sim:** add section E ancient fold with the later-wave feeder ([#398](https://github.com/juanpalopez/psychic-bassoon/issues/398)) ([b9ecce8](https://github.com/juanpalopez/psychic-bassoon/commit/b9ecce834366bd15e4e593f93552f9aa501b4666))
* **sim:** add the Bluewater Crossing section with river and bridges ([#396](https://github.com/juanpalopez/psychic-bassoon/issues/396)) ([6ee99c0](https://github.com/juanpalopez/psychic-bassoon/commit/6ee99c094429328bcf24b3337fa88718c1cdb46c))
* **sim:** add the Broken Ridge valley section ([#395](https://github.com/juanpalopez/psychic-bassoon/issues/395)) ([6638a5d](https://github.com/juanpalopez/psychic-bassoon/commit/6638a5dc73f4d72427e7f0d45b3ef19d8dbf3633))
* **sim:** add the outer march and heartkeep approach sections ([#397](https://github.com/juanpalopez/psychic-bassoon/issues/397)) ([266beba](https://github.com/juanpalopez/psychic-bassoon/commit/266beba831418b2c92b7387c1b4324b157ddcfbd))
* **sim:** add the section base class, a straight stand-in and a socket helper ([#391](https://github.com/juanpalopez/psychic-bassoon/issues/391)) ([b54ae97](https://github.com/juanpalopez/psychic-bassoon/commit/b54ae979c0653c23daef365ec5d78142558348a0))
* **sim:** add the sunken meadow section and the hero walkable graph ([#399](https://github.com/juanpalopez/psychic-bassoon/issues/399)) ([0649442](https://github.com/juanpalopez/psychic-bassoon/commit/0649442638898e979219ad93aabfff76cbf17884))
* **sim:** check each valley section and the valley as a whole ([#392](https://github.com/juanpalopez/psychic-bassoon/issues/392)) ([8f326a6](https://github.com/juanpalopez/psychic-bassoon/commit/8f326a6370fc13919d8ccd4d8c0c46f92cbf3c58)), closes [#383](https://github.com/juanpalopez/psychic-bassoon/issues/383)
* **sim:** plan the valley as six fixed sections ([#390](https://github.com/juanpalopez/psychic-bassoon/issues/390)) ([48993e9](https://github.com/juanpalopez/psychic-bassoon/commit/48993e9de19ccf8f290af5c84d9f2f8ec344f1c5))
* **sim:** play the sectioned valley on the game board ([#403](https://github.com/juanpalopez/psychic-bassoon/issues/403)) ([2be0f9f](https://github.com/juanpalopez/psychic-bassoon/commit/2be0f9f9da908911cd76fc6cd01cff3a7665b0b5))
* **sim:** stitch the six sections into a map ([#393](https://github.com/juanpalopez/psychic-bassoon/issues/393)) ([1bb6ff8](https://github.com/juanpalopez/psychic-bassoon/commit/1bb6ff87f3307ccf897c6c83d7501d18bbb19790))

## [0.1.0-alpha.3](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.2...v0.1.0-alpha.3) (2026-10-20)


### Features

* **docs:** add the homepage's fonts, art and base styles ([#371](https://github.com/juanpalopez/psychic-bassoon/issues/371)) ([70926fb](https://github.com/juanpalopez/psychic-bassoon/commit/70926fb2d78714a0c28c1b17e80eae69913f0f26))
* **docs:** add the towers, foes and workshop to the homepage ([#375](https://github.com/juanpalopez/psychic-bassoon/issues/375)) ([b0d7999](https://github.com/juanpalopez/psychic-bassoon/commit/b0d79995b4b8998d6590abd8981aa42ea69703ae))
* **docs:** style the homepage bands, towers, foes and gallery ([#373](https://github.com/juanpalopez/psychic-bassoon/issues/373)) ([306ac32](https://github.com/juanpalopez/psychic-bassoon/commit/306ac3225697db3920140801fd0ad858eade7706)), closes [#370](https://github.com/juanpalopez/psychic-bassoon/issues/370)
* **docs:** style the homepage hero, install steps and footer ([#372](https://github.com/juanpalopez/psychic-bassoon/issues/372)) ([c4dd7eb](https://github.com/juanpalopez/psychic-bassoon/commit/c4dd7eb53b86ecfe8832fa4544c2966e7e10327a))
* **docs:** switch the download page to the kingdom of the fold homepage ([#374](https://github.com/juanpalopez/psychic-bassoon/issues/374)) ([dc9dd09](https://github.com/juanpalopez/psychic-bassoon/commit/dc9dd09c0a0be55bc7f23b7bd925f7ed0d2dd7d5))
* **ui:** open the build menu as a bar along the bottom row ([#378](https://github.com/juanpalopez/psychic-bassoon/issues/378)) ([5b050dc](https://github.com/juanpalopez/psychic-bassoon/commit/5b050dc0a780aa6a02067e2458625febee871b95))


### Bug Fixes

* **ci:** let the release tag step run on demand for a commit on main ([#369](https://github.com/juanpalopez/psychic-bassoon/issues/369)) ([0d512a0](https://github.com/juanpalopez/psychic-bassoon/commit/0d512a07fcb8e082c185a4c014c24940da5b996d)), closes [#358](https://github.com/juanpalopez/psychic-bassoon/issues/358)
* **ci:** match release-please's branch name with its component suffix ([#368](https://github.com/juanpalopez/psychic-bassoon/issues/368)) ([222d0ea](https://github.com/juanpalopez/psychic-bassoon/commit/222d0ea1d9a74b0b89991ec59b45998207f0579c))

## [0.1.0-alpha.2](https://github.com/juanpalopez/psychic-bassoon/compare/v0.1.0-alpha.1...v0.1.0-alpha.2) (2026-10-19)


### Bug Fixes

* **docs:** tell the reviewer to escalate and keep the size check in light reviews ([#366](https://github.com/juanpalopez/psychic-bassoon/issues/366)) ([cce92d0](https://github.com/juanpalopez/psychic-bassoon/commit/cce92d05f9b4fe95db5289d1924045be00b2fd04))
* **ui:** line the hud up on one 88 px row ([#365](https://github.com/juanpalopez/psychic-bassoon/issues/365)) ([9caf3ac](https://github.com/juanpalopez/psychic-bassoon/commit/9caf3acadfca8dac8ea94806ba982b75fc1ba122))
