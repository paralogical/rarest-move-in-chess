import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export async function countNormalized() {
    const resultsData = JSON.parse(await readFile('results.json', { encoding: 'utf8' }));
    const counter = new CounterMap;
    for (const [move, moveCount] of Object.entries(resultsData.moves as Record<string, number>)) {
        const normalizedMove = normalizeMove(move);
        counter.add(normalizedMove, moveCount);
    }
    const sortedCounts = Object.fromEntries(Array.from(counter).sort(([, count1], [, count2]) => count2 - count1));
    const sortedCountsJson = JSON.stringify(sortedCounts, null, 4);
    console.log(sortedCountsJson);
}

const moveRegex = /^([KQRBN]?)([a-h]?[0-9]?)x?([a-h][0-9])((?:=[QRBN])?)[+#]?$/;

function normalizeMove(move: string): string {
    if (move[0] == 'O') return move.replace(/[+#]/g, ''); // castling moves
    const parts = move.match(moveRegex);
    if (parts == null) throw new Error(`unexpected move format '${move}'`);
    const [ _, piece, origin, destination, promotion ] = parts;
    const normalizedMove = `${piece}${destination}${promotion}`;
    return normalizedMove;
}

class CounterMap extends Map<string, number> {
    get(key: string): number {
        return super.get(key) ?? 0;
    }
    add(key: string, value: number) {
        return this.set(key, this.get(key) + value);
    }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
    await countNormalized();
}
