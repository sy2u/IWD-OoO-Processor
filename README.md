# MP Out-of-Order I_Wanna_Drop

## Superscalar Status

| Components | Status |
| --- | --- |
| Fetch         | ✅ Superscalar Ready |
| Decode        | ✅ Superscalar Ready |
| Rename        | ✅ Superscalar Ready |
| Dispatch      | ✅ Superscalar Ready |
| ROB           | ✅ Superscalar Ready |
| ROB (Commit)  | ✅ Superscalar Ready |
| RAT           | ✅ Superscalar Ready |
| Free List     | ✅ Superscalar Ready |
| RRF           | ✅ Superscalar Ready |
| Issue Queue   | ✅ Superscalar Ready |

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
| CP3: Bmem Arbiter         | |||✅|
| 2-Way Superscalar         |✅||||
| Split LSQ                 |✅||||
| Age-Ordered Scheduling    ||||✅|
| Branch Predictor          |||✅||

## Advanced Feature Stastic
### Age-Ordered Reservation Station
Tested with Superscalar only
| Chosen | ALU_RS | MDU_RS | Coremark | Compression | Mergesort | FFT | aes_sha 
| --- | --- | --- | --- | --- | --- | --- | --- |
| | Normal | Normal   | `0.409681` | `0.412207` | `0.593525` | `0.541800` | `0.477922` 
| | Normal | Ordered  | `0.409681` | `0.412207` | `0.593525` | `0.541800` | `0.477922` 
|✅| Ordered | Normal   | `0.425735` | `0.606571` | `0.610516` | `0.558688` | `0.490431`
| | Ordered | Ordered  | `0.425735` | `0.606571` | `0.610516` | `0.558688` | `0.490431` 
