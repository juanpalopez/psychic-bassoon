export interface Graph {
  has(path: string): boolean;
  testsReaching(path: string): string[];
}
export function buildGraph(files: Map<string, string>): Graph;
export function select(
  changed: string[],
  graph: Graph
): {godot: boolean; gut: string};
