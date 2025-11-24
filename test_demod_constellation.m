close all; clear; clc;
tic 

% get config
[Data, Params, Rcc, Viterbi, Descrambler, ReedSolomon, Huffman, DCT] = getconfig(); 

%% demod
% % create objects
% rrcRx = comm.RaisedCosineReceiveFilter( ...
%             'RolloffFactor', Rcc.rollOff, ...
%             'FilterSpanInSymbols', Rcc.spanSym, ...
%             'InputSamplesPerSymbol', Params.targetSps, ...
%             'DecimationFactor', 1 ...
%             );
% cfo = comm.CoarseFrequencyCompensator(Modulation='qpsk', SampleRate=Data.fs);
% symSync = comm.SymbolSynchronizer( ...
%             'TimingErrorDetector', 'Zero-Crossing (decision-directed)', ...
%             'SamplesPerSymbol', Params.targetSps ...
%             );
% carrierSync = comm.CarrierSynchronizer( ...
%                 'Modulation','QPSK', ...    
%                 'SamplesPerSymbol',1 ...
%                 );
% 
% % load data
% I = single(Data.raw(:,1));
% Q = single(Data.raw(:,2));
% I = clip(I, Params.minClip, Params.maxClip);
% Q = clip(Q, Params.minClip, Params.maxClip);
% I = I / max(abs(I));
% Q = Q / max(abs(Q));
% x = (I + 1j*Q);
% 
% % fir-resampling     
% xResampled = resample(x, Params.p, Params.q);
% 
% % rrc-matched-filter
% yFilteredAll = rrcRx(xResampled);
% 
% i = 1;
% symbols = [];
% while i+Params.blockSize <= numel(yFilteredAll)
%     if i+Params.blockSize <= numel(yFilteredAll)
%         yFiltered = yFilteredAll(i:i+Params.blockSize-1);
%     else
%         % if last block exceeds filesize 
%         yFiltered = yFilteredAll(i:end);
%     end
% 
%     % cfo-compensation
%     yCfo = cfo(yFiltered);
% 
%     % symbol-timing-recovery
%     ySync = symSync(yCfo);
% 
%     % carrier-recovery
%     symBlock = carrierSync(ySync);
% 
%     symbols = [symbols; symBlock];
% 
%     i = i + Params.blockSize;
% end
% 
% figure;
% plot(real(symbols(1:1000000)), imag(symbols(1:1000000)), marker='.', LineStyle='none')
% axis equal;
% axis([-2.5 2.5 -2.5 2.5]);
% grid on;
% xlabel('I-Component');
% ylabel('Q-Component');
% title('Demodulated QPSK-Symbols');
% 
% save("data/symbols.mat", "symbols");

%% constellation
% load("data/symbols.mat")
% 
% % sync word
% syncAsm = 'FCA2B63DB00D9794';
% syncAsmBytes = sscanf(syncAsm, '%2x').';
% syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
% syncAsmBits = reshape(syncAsmBits.', 1, []);
% syncAsmBits = 2*double(syncAsmBits)-1;
% 
% i = 1;
% constellationErrorLast = 0;
% constellationErrorFirst = 0;
% lastFrame = 0;
% softBitsAll = [];
% while i < numel(symbols)
%     if i+Params.blockSize-1 < numel(symbols)
%         symbolsBlock = symbols(i:i+Params.blockSize-1);
%     else
%         lastFrame = 1;
%         symbolsBlock = symbols(i:end);
%     end
%     % constellation rotation and symmetry
%     for j=1:length(Params.constellations)
%         % qpsk demodulation soft-decoding
%         softBits = pskdemod( ...
%                     symbolsBlock, ...
%                     Params.M, ...
%                     pi/4, ...
%                     Params.constellations{j}, ...
%                     OutputType="llr" ...
%                     );
% 
%         % cross-correlation
%         [corr, lags] = xcorr(softBits, syncAsmBits);
%         corrNormalized = abs(corr)./max(abs(corr));
%         signalLevel = quantile(abs(corrNormalized), 0.999);
% 
%         % peak-noise distance is to small
%         if signalLevel > 0.6
%             continue
%         end
% 
%         % find peaks and calculate widths
%         [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevel+0.2); % , 'MinPeakHeight', 40+signalLevel
%         widths = diff(locs)/16;
% 
%         % check if we are in the negative case
%         if corr(locs) < 0
%             softBits = -softBits;
%         end
% 
%         if all(widths == 1024)
%             firstPeak = locs(1);
%             expectedNumPeaks = ceil(numel(corrNormalized(firstPeak:end))/16384);
% 
%             % last few frames have different constellation
%             if expectedNumPeaks ~= numel(locs)
%                 part1 = softBits(1:lags(locs(end))+16384);
%                 part2 = symbolsBlock(lags(locs(end))/2+1+8192+1:end);
%                 softBits = constellation2(1, part2, Params);
%                 constellationErrorLast = 1; 
% 
%             % first few frames have different constellation
%             elseif lags(locs(1)) > 16384+1
%                 part2 = softBits(lags(locs(1))-1:end);
%                 part1 = symbolsBlock(1:lags(locs(1))/2-1);
%                 softBits = constellation2(1, part1, Params);
%                 constellationErrorFirst = 1; 
%             end
%         end
% 
%         if constellationErrorLast
%             constellationErrorLast = 0;
%             softBitsCombined = [part1; softBits];
%             [corr, lags] = xcorr(softBitsCombined, syncAsmBits);
%             corrNormalized = abs(corr)./max(abs(corr));
%             signalLevel = quantile(abs(corrNormalized), 0.999);
%             [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevel+0.2); % , 'MinPeakHeight', 40+signalLevel
%             softBitsConfirmed = softBitsCombined(1:lags(locs(end)));
%             break
%         elseif constellationErrorFirst
%             constellationErrorFirst = 0;
%             softBitsCombined = [softBits; part2];
%             [corr, lags] = xcorr(softBitsCombined, syncAsmBits);
%             corrNormalized = abs(corr)./max(abs(corr));
%             signalLevel = quantile(abs(corrNormalized), 0.999);
%             [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevel+0.2); % , 'MinPeakHeight', 40+signalLevel
%             softBitsConfirmed = softBitsCombined(1:lags(locs(end)));
%             break
%         elseif all(~mod(widths, 1024)) && lastFrame
%             softBitsConfirmed = softBits;
%         elseif all(~mod(widths, 1024)) && ~lastFrame
%             softBitsConfirmed = softBits(1:lags(locs(end)));
%             break
%         end
%     end
%     softBitsAll = [softBitsAll; softBitsConfirmed];
% 
%     % [cvcdus, payloads, decodedBits] = decode(softBitsAll, Viterbi, Descrambler, Params);
%     i = i + numel(softBitsConfirmed)/2;
% end
% save("data/softBits.mat", "softBitsAll");
% [cvcdus, payloads, decodedBits] = decode(softBitsAll, Viterbi, Descrambler, Params);

%% extraction
load("data/cvcdus.mat")
[mcus, qualityFactors, apids] = extraction(cvcdus);
% 
% load("data/softbits.mat");
% softBits = softBitsAll;
% [cvcdus, payloads, decodedBits] = decode(softBits, Viterbi, Descrambler, Params);