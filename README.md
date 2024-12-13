# IWD
IWD is a 2-way superscalar, OoO processor that focuses on a short pipeline and low instruction latency. Course final project of ECE411@UIUC FA24.

Joint effort of [Chiming Ni](https://github.com/nice-mee), [Kongning Lai](https://github.com/kongninglai), [Siying Yu](https://github.com/FlippingLogic), and [Hengjia Yu](https://github.com/siriuxyu).

## Design
![MP_OOO drawio](https://github.com/user-attachments/assets/c68859df-0414-4d0e-919b-69aff6267dbe)

## Benchmarks


## Contribution
| Deliverable | Chiming Ni | Hengjia Yu | Kongning Lai | Siying Yu |
| --- | --- | --- | --- | --- |
| CP1: Frontend             |✅ |   |   | |
| CP1: Cacheline Adapter    |✅ |   |✅ | |
| CP1: FIFO                 |✅ |   |  | ✅ |
| CP1: Block Diagram        |✅ | ✅ | | |
| CP2: Decode & Rename & Dispatch   | ✅ | | | |
| CP2: Reservation Stations |   |   | ✅ | |
| CP2: RV32M Integration    |   |✅| |✅|
| CP2: ROB                  |   |✅ |  |  |
| CP2: RAT & RRF            |   |   | |✅ |
| CP2: Free List            |✅ |  | | |
| CP3: Memory Subsystem     |✅ ||||
| CP3: Branches             | ||✅||
| CP3: BMEM Arbiter         | |||✅|
| 2-Way Superscalar         |✅||||
| Split LSQ                 |✅||||
| Post-Commit Store Buffer  |✅||||
| Age-Ordered Scheduling    ||||✅|
| Branch Predictor (FF Gshare+uBTB) |||✅||
| Pipelined Mul/Div         ||✅|||
| Dual Issue    ||||✅|
