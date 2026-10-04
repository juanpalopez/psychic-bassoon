import {buildReport, parseArgs} from './report';

try {
  console.log(buildReport(parseArgs(process.argv.slice(2))));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  console.error('usage: pnpm sim -- [--seed N] [--waves N] [--speed 1-3]');
  process.exitCode = 1;
}
