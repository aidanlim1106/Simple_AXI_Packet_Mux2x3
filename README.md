# RTL Packet Multiplexer Design

A SystemVerilog-based packet multiplexer featuring fair arbitration, control word parsing, and error detection. This project demonstrates a complete RTL flow from architectural considerations to verification and timing constraints.

---

## Project Structure

The repository is organized to separate design intent from verification and legacy iterations:

* **`rtl/`**: Core SystemVerilog design files.
* **`tb/`**: Testbench suite and simulation logs.
* **`old/`**: Historical code versions and early design structures for reference.

### Key Files
| File | Description |
| :--- | :--- |
| **`packet_mux_top.sv`** | Top-level module: handles control word parsing, routing, and error detection. |
| **`param_pkg.sv`** | Global parameters, enums, and struct definitions for design consistency. |
| **`round_robin_arbiter.sv`** | Implements fair arbitration between M0 and M1 using a `granted_last` flag. |
| **`stat_counter.sv`** | Statistics module tracking packet and byte counts per interface. |
| **`tb_packet_mux.sv`** | Verification suite featuring 16 distinct test cases. |
| **`outputFINAL`** | Log file showing 16/16 passed test cases from the Aldec simulator. |

---

## Design & Timing Considerations

The design was developed with industry-standard constraints in mind. A `constraints.sdc` file is provided (formatted with AI assistance for Synopsys Design Constraints compatibility).

* **Clocking**: Operates on a single clock domain (`aclk`), simplifying timing closure.
* **Reset Strategy**: Uses asynchronous active-low reset logic.
* **Critical Path**: The primary timing-critical path spans from the **Arbiter** through the **Router** logic to the **Slave outputs**.
* **Pipelining**: A `ROUTER_PROCESS` state was implemented to add a clock cycle, ensuring safe and stable parsing of the control word.

---

## Verification Environment

The design was validated using the following environment:

* **Platform**: EDA Playground
* **Simulator**: Aldec Riviera-PRO 2023.04
* **Timescale**: 1ns / 1ns
* **Clock Period**: 10ns (100MHz)

### Test Coverage
The testbench includes 16 test cases covering:
- [x] **Routing**: M0/M1 to S0/S1/S2 (verified 2 cycles per packet).
- [x] **Packet Variations**: Single-beat ($length=1$), Medium ($length=5$), and Long ($length=10$).
- [x] **Arbitration Logic**: Simultaneous M0/M1 requests and back-to-back alternating master requests.
- [x] **Error Handling**: Detection and reporting of Illegal Destination errors for both masters.

---

## Getting Started

To view the results or run the simulation:
1. Load the files in the `rtl/` and `tb/` folders into your SystemVerilog simulator.
2. Ensure `param_pkg.sv` is compiled first to resolve dependencies.
3. Run the testbench `tb_packet_mux.sv` to see the 16 test cases execute.
