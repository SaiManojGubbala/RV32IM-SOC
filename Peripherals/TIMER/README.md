# Timer Peripheral

Memory-mapped countdown/count-up timer with interrupt output. Register-file style peripheral (address + data + write enable), combinational read and sequential write/count logic.

## HandWritten Notes
<img width="2643" height="1587" alt="1000041820" src="https://github.com/user-attachments/assets/9691d3d3-acca-4f6b-8bab-5fdf024b9156" />
<img width="2609" height="1575" alt="1000041821" src="https://github.com/user-attachments/assets/f87d401a-7299-4a31-981b-34aab2c5e5e4" />
<img width="2677" height="1540" alt="1000041822" src="https://github.com/user-attachments/assets/69c74864-02ac-4e5e-980f-45b31612a9cf" />


## Module Interface

```verilog
module TIMER (
    clk, reset, write_enable_in,
    address_in, data_in, data_out,
    send_interrupt
);
```

| Signal            | Direction | Width | Description                     |
|--------------------|-----------|-------|-----------------------------------|
| `clk`              | input     | 1     | Bus clock                        |
| `reset`            | input     | 1     | Active-high reset                |
| `write_enable_in`  | input     | 1     | Bus write strobe                 |
| `address_in`       | input     | 32    | Register address from bus        |
| `data_in`          | input     | 32    | Write data from bus              |
| `data_out`         | output reg| 32    | Read data to bus (combinational) |
| `send_interrupt`   | output    | 1     | Interrupt line, asserted on timer completion |

## Register Map

| Address      | Register | Access | Description                     |
|--------------|----------|--------|-----------------------------------|
| `0x0`        | `ctrl`   | R/W    | Status + control bits            |
| `0x4`        | `count`  | R      | Live counter value (read-only from bus) |
| `0x8`        | `value`  | R/W    | Target count / compare value      |

## `ctrl` Bit Layout

| Bit | Name    | Meaning                                                      |
|-----|---------|----------------------------------------------------------------|
| 0   | pending | 1 = counting is pending/in-progress, 0 = counting completed (auto-cleared by hardware on completion) |
| 1   | enable  | 1 = counter enabled/running, 0 = counter disabled (forces `count` to 0) |
| 2   | done    | 1 = counting completed (set by hardware); writing `data_in[2] = 1` clears it, otherwise it's left as-is |

## Behavior

### Read (combinational, `always @(*)`)
- `reset == 1`: `data_out = 0`.
- Else, based on `address_in[3:0]`: returns `ctrl`, `count`, or `value` per the register map above.

### Write (sequential, `posedge clk`)
- `reset == 1`: clears `ctrl` and `value` to 0. (`count` is cleared separately in the counter block.)
- Else, if `write_enable_in == 1`:
  - Write to `ctrl` (address `0x0`): bits `[31:3]` and `[1:0]` are taken directly from `data_in`. Bit 2 (`done`) is handled specially — it's cleared if `data_in[2] == 1` (software acknowledges/clears completion), otherwise the existing `ctrl[2]` value is preserved (hardware-set completion isn't overwritten by an unrelated write).
  - Write to `value` (address `0x8`): straight `data_in` capture — sets the new target count.
  - `count` has no direct write path; it's bus-read-only.
- Else (`write_enable_in == 0`) — **completion check**: if `ctrl[0] == 1` (counting pending) and `count >= value`, hardware sets `ctrl[0] <= 0` (no longer pending) and `ctrl[2] <= 1` (mark completed).

### Counter Update (separate sequential block, `posedge clk`)
- `reset == 1`: `count <= 0`.
- Else, if `ctrl[1:0] == 2'b11` (both enabled **and** pending):
  - `count < value` → increment: `count <= count + 1`.
  - `count >= value` → wrap: `count <= 0`.
- Else (disabled or not pending): `count <= 0` — counter is held at zero whenever it's not actively running.

### Interrupt

```verilog
assign send_interrupt = ctrl[2] && ctrl[1];
```
Asserted when the timer has completed (`ctrl[2] == 1`, "done") **and** the timer is enabled (`ctrl[1] == 1`). Software typically clears this by writing `data_in[2] = 1` to the `ctrl` register.

## Typical Usage Flow

1. Write target count to `value` (`0x8`).
2. Write `ctrl = 0b11` (`0x0`) → sets pending (bit 0) and enable (bit 1), starts counting from 0.
3. Counter increments each cycle until `count >= value`, then wraps to 0.
4. Same cycle the completion condition is met, hardware clears bit 0 (pending) and sets bit 2 (done) → `send_interrupt` goes high (since enable is still 1).
5. Software services the interrupt, then writes `ctrl` with `data_in[2] = 1` to clear the done flag (while `[1:0]` bits determine whether it restarts).

## Notes
- `count` cannot be written directly by the bus — only observed. The only way to reset it mid-run is to clear `ctrl[1]` (disable) or hit `reset`.
- Completion (`ctrl[0]` clear + `ctrl[2]` set) is checked only when `write_enable_in == 0` — a bus write in the same cycle the timer completes will suppress that cycle's completion update, since the write branch takes priority in the same always block.
- All `ctrl` field assignments in the clocked blocks are non-blocking (`<=`), including the hardware-driven completion path — required since blocking assignments on the same signal across branches of one clocked `always` block can cause simulation/synthesis mismatches.
