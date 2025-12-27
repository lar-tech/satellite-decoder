# Satellite Decoder – LRPT (Meteor-M2)

This repository contains a prototype software receiver for LRPT signals transmitted by the Russian Earth observation satellites of the Meteor-M2 series.
The project was developed as part of the university module Funksysteme at Technische Universität Berlin and demonstrates a complete digital satellite reception chain, from complex baseband samples to reconstructed Earth observation images.
The focus of this work is a transparent MATLAB implementation of the physical-layer and data-link-layer processing steps based on CCSDS standards.

## Project Scope
LRPT (Low Rate Picture Transmission) is a digital downlink used by Meteor-M2 satellites to transmit multispectral Earth imagery.  
This project implements the core signal processing and decoding steps required to recover image data from recorded LRPT signals.

Implemented functionality includes:
- Carrier and symbol synchronization  
- QPSK demodulation  
- Channel decoding according to CCSDS  
- Frame synchronization and parsing  
- JPEG-like image reconstruction  
- Visualization of intermediate and final results  

---

## Signal Processing Chain

The receiver architecture follows the processing pipeline below:

1. IQ Input:
    - Complex baseband samples (e.g. from SDR recordings)
2. Carrier Recovery & Filtering
   - Frequency and phase correction  
   - Root-Raised-Cosine filtering
3. Demodulation
   - QPSK demodulation  
   - Symbol timing recovery
4. Frame Synchronization
   - Detection of the Attached Sync Marker (ASM)
5. Channel Decoding
   - Viterbi decoding (convolutional code)  
   - Reed-Solomon decoding  
   - CCSDS derandomization
6. Packet and Image Processing
   - LRPT frame parsing  
   - JPEG-like decompression  

## Standards and References
The implementation is based on the following standards and specifications:
- CCSDS 131.0-B – TM Synchronization and Channel Coding  
- CCITT T.81 / ISO/IEC 10918-1 – JPEG Baseline DCT  
- Publicly available documentation of the Meteor-M2 LRPT protocol  
All relevant standards and theoretical background are discussed in detail in the accompanying project report.

## Repository Structure

```text
.
├── src/
│   ├── constellation.m
│   ├── decode.m
│   ├── demod.m
│   ├── extraction.m
│   ├── getconfig.m
│   ├── huffman.m
│   ├── jpegdecoding.m
│   └── qualitycheck.m
│
├── data/
│   ├── meteor_m2_72k.wav # example recording
│   ├── report.pdf
│   ├── presentation.pdf
│   └── plots/
│
├── main.m
└── README.md
```

## Requirements
- MATLAB (recommended: R2022b or newer)
- Image Processing Toolbox
- Communications Toolbox

Optional:
- SDR hardware (e.g. RTL-SDR) for recording custom IQ data

## Usage
	1.	Place IQ recordings in data/ folder
	2.	Run the main `main.m`

All relevant parameters (sampling rate, symbol rate, filters) are documented in the `getconfig.m` and can be changed accordingly in the source code.

## Authors
Anton Valentin Dilg, Ramin Leon Neymeyer, Ramon Rennert, Steffen August Sigwart

Technische Universität Berlin, Faculty of Electrical Engineering and Computer Science

## License
This project is licensed under the MIT License