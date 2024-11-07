# FA 24 TEST CASES

## Coremark
* Industry standard benchmarking suite

## FFT
* Performs Fast Fourier Transform on multiple input signals
* Utilizes arithmetic units heavily
* Expresses good ILP

## Mergesort
* Performs merge sort on multiple input arrays
* Many data-dependent branches
* Many loads/stores
 
## AES-SHA
* Performs AES encryptions and SHA-256 hash on input stream
* Has data reuse
* Utilizes arithmetic units heavily
* Expresses good ILP
* Many loads/stores, with high memory-level parallelism
  
