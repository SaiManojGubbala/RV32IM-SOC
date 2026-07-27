# Instruction Memory (ROM)

Memory-mapped instruction memory for the bus. Same underlying module structure as `data_memory`, renamed to `instruction_memory`. Word-addressed, asynchronous read, synchronous write.

## HandWritten Notes
<img width="2691" height="1541" alt="1000041819" src="https://github.com/user-attachments/assets/95dab6bb-082c-4a39-9987-bf53742ad3d1" />

## Module Interface

```verilog
module instruction_memory (
    clk, reset, write_enable_in,
    address_in, data_in, data_out
);
```

| Signal            | Direction | Width | Description                     |
|--------------------|-----------|-------|-----------------------------------|
| `clk`              | input     | 1     | Bus clock                        |
| `reset`            | input     | 1     | Active-high reset (affects read output only) |
| `write_enable_in`  | input     | 1     | Write strobe (unused by core — see note below) |
| `address_in`       | input     | 32    | Byte address from bus / instruction fetch |
| `data_in`          | input     | 32    | Write data (unused by core — see note below) |
| `data_out`         | output reg| 32    | Instruction/read data to bus (combinational) |

## Memory Array

```verilog
reg [31:0] MEMORY [0:8191];
```

- **Depth:** 8192 words (`MEMDEPTH = 0:8191`)
- **Word size:** 32 bits
- **Total size:** 32 KB
- **Addressing:** word-addressed internally. `address_in[14:2]` (`MEMADDRESS`) is used as the index, dropping byte-offset bits `[1:0]`.

## Behavior

### Read (combinational, `always @(*)`)
- Asynchronous / unclocked read path.
- `reset == 1`: `data_out = 0`.
- Else: `data_out = MEMORY[address_in[14:2]]` — this is the instruction fetch path the core uses every cycle.

### Write (sequential, `posedge clk`)
- `write_enable_in == 1`: `MEMORY[address_in[14:2]] <= data_in` on the clock edge.
- **The core itself never drives `write_enable_in` high for this module** — instructions are expected to be preloaded (e.g. via `$readmemh`/`$readmemb` at simulation init, or synthesis-time initialization).
- The write port is kept in the RTL intentionally, not removed, to support **future boot-loading paths** — e.g. JTAG or UART loading a program into this memory before/without CPU involvement. Right now it's dead logic from the core's perspective, but it's the hook for that future feature.

## Notes
- Functionally identical to `data_memory` — same depth, same addressing scheme, same read/write timing. Only the name and intended usage differ (instruction fetch vs. data load/store).
- Because the write path is unused by the core today, current instruction content in simulation must come from an initial memory load, not CPU stores.
- When JTAG/UART boot-loading is added later, that block would drive `write_enable_in`, `address_in`, and `data_in` on this same port — no RTL changes to this module should be needed, just a new master driving these signals.
- Same caveats as `data_memory`: reset clears `data_out` only, not memory contents; address bits `[1:0]` are ignored (word-aligned access only).
