import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { readFitLocalTimestamp } from './read-fit-local-timestamp';

const sampleFitPath = path.join(process.cwd(), 'src/testing/fixtures/20260501174139.fit');

describe('readFitLocalTimestamp', () => {
  it('reads local_timestamp from a Coros-exported FIT file', async () => {
    const timestamp = readFitLocalTimestamp(await readFile(sampleFitPath));

    expect(timestamp).toEqual(new Date(Date.UTC(2026, 4, 1, 17, 41, 39)));
  });

  it('returns undefined for non-FIT buffers', () => {
    expect(readFitLocalTimestamp(Buffer.from('not a fit file'))).toBeUndefined();
  });

  it('returns undefined for buffers that are too short', () => {
    expect(readFitLocalTimestamp(Buffer.alloc(8))).toBeUndefined();
  });
});
