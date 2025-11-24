function softBitsConfirmed = constellation2(recursive, symbols, Params)
    % sync word
    syncAsm = 'FCA2B63DB00D9794';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', 1, []);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    i = 1;
    while i <= numel(symbols)
        if i+Params.blockSize-1 < numel(symbols)
        symbolsBlock = symbols(i:i+Params.blockSize-1);
        else
            symbolsBlock = symbols;
        end
        % constellation rotation and symmetry
        for j=1:length(Params.constellations)
            % qpsk demodulation soft-decoding
            softBits = pskdemod( ...
                        symbolsBlock, ...
                        Params.M, ...
                        pi/4, ...
                        Params.constellations{j}, ...
                        OutputType="llr" ...
                        );
        
            % cross-correlation
            [corr, lags] = xcorr(softBits, syncAsmBits);
            corrNormalized = abs(corr)./max(abs(corr));
            signalLevel = quantile(abs(corrNormalized), 0.999);
        
            % peak-noise distance is to small
            if signalLevel > 0.6
                continue
            end
        
            % find peaks and calculate widths
            [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevel+0.15); % , 'MinPeakHeight', 40+signalLevel
            widths = diff(locs)/16;
        
            % check if we are in the negative case
            if corr(locs) < 0
                softBits = -softBits;
            end
        
            if all(widths == 1024)
                firstPeak = locs(1);
                expectedNumPeaks = ceil(numel(corrNormalized(firstPeak:end))/16384);
        
                % last few frames have different constellation
                if expectedNumPeaks ~= numel(locs)
                    part1 = softBits(1:lags(locs(end))+16384);
                    part2 = symbols(lags(locs(end))/2+8192+1:end);
                    softBits = constellation(part2, Params);
                    constellationErrorLast = 1; %#ok used for flag
        
                % first few frames have different constellation
                elseif lags(locs(1)) > numel(softBits)/2
                    part2 = softBits(lags(locs(1))-1:end);
                    part1 = symbols(1:lags(locs(1))/2-1);
                    softBits = constellation(part1, Params);
                    constellationErrorFirst = 1; %#ok used for flag
                end
            end
            
            if exist("constellationErrorLast", "var")
                softBits = [part1; softBits];
            elseif exist("constellationErrorFirst", "var")
                softBits = [softBits; part2];
            end
        
            if all(widths == 1024) && ~recursive
                softBitsConfirmed = softBits(1:lags(locs(end)));
                break
            elseif all(widths == 1024) && recursive
                softBitsConfirmed = softBits;
                break
            end
        end
        i = i + numel(softBitsConfirmed)/2;
    end
end