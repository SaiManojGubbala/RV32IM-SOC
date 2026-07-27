# GPIO Peripheral

Memory-mapped GPIO controller with a 2-pin bidirectional interface. Bus-connected register-file style peripheral (address + data + write enable), combinational read and sequential write/sample logic.

## HandWritten Notes 

<img width="2735" height="1692" alt="1000041810" src="https://github.com/user-attachments/assets/5822a83a-342b-40e0-8706-072579531f9a" />

<img width="2589" height="1560" alt="1000041811" src="https://github.com/user-attachments/assets/49eb5733-cd2d-4a02-a5aa-c6846ab267ee" />

<img width="2750" height="1560" alt="1000041816" src="https://github.com/user-attachments/assets/bb55a313-af44-4a08-a82c-7b1997abf15b" />

## Module Interface

```verilog
module gpio (
    clk, reset, --> clock is used for synchronous write and asynchronous read
    data_in, address_in,
    data_out, write_enable_in,
    pins
);
```

| Signal            | Direction | Width | Description                          |
|--------------------|-----------|-------|---------------------------------------|
| `clk`              | input     | 1     | Bus clock                             |
| `reset`            | input     | 1     | Synchronous/async-style reset (active high) |
| `data_in`          | input     | 32    | Write data from bus                   |
| `address_in`       | input     | 32    | Register address from bus              |
| `data_out`         | output reg| 32    | Read data to bus (combinational)      |
| `write_enable_in`  | input     | 1     | Bus write strobe                      |
| `pins`             | inout     | 2     | Physical GPIO pins (`pins[0]`, `pins[1]`) |

## Register Map

| Address      | Register       | Access | Description                     |
|--------------|----------------|--------|----------------------------------|
| `0x0000_0000`| `mask_enable`  | R/W    | Direction + enable config per pin |
| `0x0000_0004`| `data`         | R/W    | Pin data (output value / captured input value) |

Any other address returns `32'b0` on read and is ignored on write.

## `mask_enable` Bit Layout

Each pin gets 2 config bits: `[direction, enable]`.

| Bits      | Pin  | Bit 0 (LSB)         | Bit 1               |
|-----------|------|---------------------|---------------------|
| `[1:0]`   | pin0 | direction (0=in, 1=out) | enable (0=disabled, 1=enabled) |
| `[3:2]`   | pin1 | direction (0=in, 1=out) | enable (0=disabled, 1=enabled) |

So per pin: `mask_enable = {enable, direction}`.

## Behavior

### Read (combinational, `always @(*)`)
- Asynchronous / unclocked read path.
- `reset == 1`: `data_out = 0`.
- `address_in == 0x0`: `data_out = mask_enable`.
- `address_in == 0x4`: `data_out = data`.
- Any other address: `data_out = 0`.

### Write / Sample (sequential, `posedge clk`)
- `reset == 1`: clears both `data` and `mask_enable` to `0`.
- Else, if `write_enable_in == 1`:
  - `address_in == 0x0` → `mask_enable <= data_in`
  - `address_in == 0x4` → `data <= data_in`
- Else (`write_enable_in == 0`) — **input sampling**:
  - If `mask_enable[1:0] == 2'b10` (pin0 enabled + configured as input), latch `data[0] <= pins[0]`.
  - If `mask_enable[3:2] == 2'b10` (pin1 enabled + configured as input), latch `data[1] <= pins[1]`.

Note: sampling only checks for the exact pattern `2'b10` (enabled + input). If a pin is disabled (`enable = 0`), it is **not** sampled and its `data` bit holds its previous value.

### Pin Drivers (continuous assignment)

```verilog
assign pins[0] = mask_enable[1] ? (mask_enable[0] ? data[0] : 1'bz) : 1'bz;
assign pins[1] = mask_enable[3] ? (mask_enable[2] ? data[1] : 1'bz) : 1'bz;
```

| enable | direction | Pin drive         |
|--------|-----------|--------------------|
| 0      | x         | High-Z (`1'bz`)    |
| 1      | 0 (input) | High-Z (`1'bz`)    |
| 1      | 1 (output)| Drives `data[n]`   |

So a pin only actively drives when it's **enabled AND configured as output**; otherwise it floats (`z`), which is also the state it needs to be in to be readable as an input.

## Usage Example

To configure pin0 as output and drive it high:
```
write(0x0, 32'b11);   // enable=1, direction=1 (output) for pin0
write(0x4, 32'b1);    // data[0] = 1 -> pins[0] driven high
```

To configure pin1 as input and read it:
```
write(0x0, 32'b1000_00); // bits[3:2] = 2'b10 -> pin1 enabled, input
// on next clock edge (write_enable_in low), pins[1] gets sampled into data[1]
read(0x4);                // data_out returns captured value
```

## Notes / Gotchas
- Only 2 pins are hardcoded — not parameterized for wider GPIO ports.
- Input sampling happens on **every clock edge** whenever `write_enable_in == 0`, regardless of address_in — it's not gated by a specific "read" address.
- `data` is dual-purpose: holds the output value driven onto the pin, but also gets overwritten by sampled input values when configured as input. Don't expect the last-written output value to persist if the pin is later switched to input mode.



