# MP Out-of-Order I_Wanna_Drop

## Superscalar Status

| Components | Status |
| --- | --- |
| Fetch         | ✅ Superscalar Ready  |
| Decode        | ✅ Superscalar Ready  |
| Rename        | ❌ RAW & WAW Issue    |
| Dispatch      | ✅ Superscalar Ready  |
| ROB           | ✅ Superscalar Ready  |
| ROB (Commit)  | ❌ Store Issue        |
| RAT           | ❌ Not Implemented Yet|
| Free List     | ❌ Not Implemented Yet|
| RRF           | ✅ Superscalar Ready  |
| Issue Queue   | ❌ Not Implemented Yet|

## Contribution
| Deliverable | Chiming Ni | Hengjia Yu | Kongning Lai | Siying Yu |
| --- | --- | --- | --- | --- |
| CP1: Frontend             |✅ |   |   | |
| CP1: Cacheline Adapter    |✅ |   |✅ | |
| CP1: FIFO                 |✅ |   |  | ✅ |
| CP1: Block Diagram        |✅ | ✅ | | |
| CP2: Decode & Rename & Dispatch   | ✅ | | | |
| CP2: Reservation Stations |   |   | ✅ | |
| CP2: RV32M Integration    |   |   | |✅|
| CP2: ROB                  |   |✅ |  |  |
| CP2: RAT & RRF            |   |   | |✅ |
| CP2: Free List            |✅ |  | | |
| CP3: Memory Subsystem     |✅ ||||
| CP3: Branches             | ||✅||
| CP3: Bmem Arbiter         | |||✅|

## Advanced Feature Stastic
### Age-Ordered Reservation Station
Tested with Superscalar only
| RS / Benchmark | Coremark | Compression | Mergesort | FFT | aes_sha
| --- | --- | --- | --- | --- |
| INT_Normal  w/ INTM_Normal   | 0.409681 | 0.412207 | 0.593525 | 0.541800 | 0.477922
| INT_Normal  w/ INTM_Ordered  | 0.409681 | 0.412207 | 0.593525 | 0.541800 | 0.477922
| INT_Ordered w/ INTM_Normal   | 0.425735 | 0.606571 | 0.610516 | 0.558688 | 0.490431
| INT_Ordered w/ INTM_Ordered  | 0.425735 | 0.606571 | 0.610516 | 0.558688 | 0.490431
