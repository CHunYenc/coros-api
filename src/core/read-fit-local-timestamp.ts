// Seconds between the Unix epoch and the FIT epoch (1989-12-31T00:00:00Z), used to convert
// FIT's uint32 timestamps into standard Unix time.
const FIT_EPOCH_OFFSET_SECONDS = 631065600;

// FIT global message number for `activity`. Its field 5 (`local_timestamp`) holds the device's
// local wall-clock time when the activity was recorded, e.g. `2026-05-01T17:41:39` — this is what
// Coros historically used to name exported files (`20260501174139.fit`).
const ACTIVITY_GLOBAL_MESSAGE_NUMBER = 34;
const LOCAL_TIMESTAMP_FIELD_NUMBER = 5;

type MessageDefinition = {
  globalMessageNumber: number;
  littleEndian: boolean;
  fields: { fieldNumber: number; size: number }[];
};

/**
 * Reads the `local_timestamp` field out of a FIT file's `activity` message.
 *
 * The returned Date's UTC fields (getUTC*) represent the device's local time as-is — no timezone
 * conversion is needed/possible, since FIT only stores the local wall-clock value here.
 *
 * Returns undefined if the buffer isn't a FIT file or the field can't be found (e.g. unsupported
 * message layout), so callers can fall back to another naming scheme.
 */
export function readFitLocalTimestamp(buffer: Buffer): Date | undefined {
  if (buffer.length < 12 || buffer.toString('ascii', 8, 12) !== '.FIT') {
    return undefined;
  }

  const headerSize = buffer[0]!;
  let offset = headerSize;
  const localMessageDefinitions = new Map<number, MessageDefinition>();

  try {
    while (offset < buffer.length) {
      const recordHeader = buffer[offset]!;
      offset += 1;

      // Compressed-timestamp headers (bit 7 set) are only used for data messages and encode the
      // local message type differently; we don't need the embedded time offset here.
      const isCompressedTimestamp = (recordHeader & 0x80) !== 0;
      const isDefinition = !isCompressedTimestamp && (recordHeader & 0x40) !== 0;
      const localMessageType = isCompressedTimestamp ? (recordHeader >> 5) & 0x03 : recordHeader & 0x0f;

      if (isDefinition) {
        const littleEndian = buffer[offset + 1] === 0;
        const globalMessageNumber = littleEndian ? buffer.readUInt16LE(offset + 2) : buffer.readUInt16BE(offset + 2);
        const fieldCount = buffer[offset + 4]!;
        offset += 5;

        const fields: MessageDefinition['fields'] = [];
        for (let i = 0; i < fieldCount; i++) {
          fields.push({ fieldNumber: buffer[offset]!, size: buffer[offset + 1]! });
          offset += 3;
        }

        // Developer-data fields (bit 5 of the header) aren't needed, but must be skipped over.
        if ((recordHeader & 0x20) !== 0) {
          const devFieldCount = buffer[offset]!;
          offset += 1 + devFieldCount * 3;
        }

        localMessageDefinitions.set(localMessageType, { globalMessageNumber, littleEndian, fields });
        continue;
      }

      const definition = localMessageDefinitions.get(localMessageType);
      if (!definition) return undefined;

      if (definition.globalMessageNumber === ACTIVITY_GLOBAL_MESSAGE_NUMBER) {
        let fieldOffset = offset;
        for (const field of definition.fields) {
          if (field.fieldNumber === LOCAL_TIMESTAMP_FIELD_NUMBER && field.size === 4) {
            const seconds = definition.littleEndian
              ? buffer.readUInt32LE(fieldOffset)
              : buffer.readUInt32BE(fieldOffset);
            return new Date((seconds + FIT_EPOCH_OFFSET_SECONDS) * 1000);
          }
          fieldOffset += field.size;
        }
      }

      offset += definition.fields.reduce((sum, field) => sum + field.size, 0);
    }
  } catch {
    return undefined;
  }

  return undefined;
}
