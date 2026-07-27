# Data Memory (RAM)

Memory-mapped data RAM peripheral for the bus. Word-addressed, asynchronous read, synchronous write.

## HandWritten Notes
<img width="2622" height="1522" alt="1000041818" src="https://github.com/user-attachments/assets/6d1f763b-e725-4c78-813f-2c89b75343e7" />

## Module Interface

```verilog
module data_memory (
    clk, reset, write_enable_in,
    address_in, data_in, data_out
);
```

| Signal            | Direction | Width | Description                     |
|--------------------|-----------|-------|-----------------------------------|
| `clk`              | input     | 1     | Bus clock                        |
| `reset`            | input     | 1     | Active-high reset (affects read output only) |
| `write_enable_in`  | input     | 1     | Bus write strobe                 |
| `address_in`       | input     | 32    | Byte address from bus            |
| `data_in`          | input     | 32    | Write data from bus              |
| `data_out`         | output reg| 32    | Read data to bus (combinational) |

## Memory Array

```verilog
reg [31:0] MEMORY [0:8191];
```

- **Depth:** 8192 words (`MEMDEPTH = 0:8191`)
- **Word size:** 32 bits
- **Total size:** 32 KB
- **Addressing:** word-addressed internally. `address_in[14:2]` (`MEMADDRESS`) is used as the index — this drops the byte-offset bits `[1:0]` (since accesses are word-aligned) and covers exactly `2^13 = 8192` locations.

## Behavior

### Read (combinational, `always @(*)`)
- Asynchronous / unclocked read path.
- `reset == 1`: `data_out = 0`.
- Else: `data_out = MEMORY[address_in[14:2]]` — continuously reflects whatever is at the addressed location.

### Write (sequential, `posedge clk`)
- `write_enable_in == 1`: `MEMORY[address_in[14:2]] <= data_in` on the clock edge.
- No `reset` handling on write side — reset only clears `data_out`, it does **not** clear the memory contents.
- No `else` branch — when not writing, the memory array is simply left untouched (read path already handles output independently).

## Notes
- This is a single read/write port RAM: one address bus is shared for both read and write, so you can't read one location and write another in the same cycle.
- Since read is asynchronous (combinational), `data_out` updates immediately when `address_in` changes — no clock edge needed to see new data, unlike a synchronous-read RAM.
- Memory contents persist across `reset` — only the read-out register logically shows zero during reset, the underlying `MEMORY` array is unaffected.
- Address bits `[1:0]` are ignored (word-aligned access only) — sub-word/byte access is not supported by this module as written.
