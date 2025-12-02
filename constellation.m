function softBitsAll = constellation(recursive, symbols, Params)
    function softBitsConfirmed = findPeaksConstellationError(softBitsCombined, syncAsmBits)
        [corrError, lags] = xcorr(softBitsCombined, syncAsmBits);
        corrNormalized = abs(corrError)./max(abs(corrError));
        signalLevelError = quantile(abs(corrNormalized), 0.999);
        [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevelError+0.2); % , 'MinPeakHeight', 40+signalLevel
        softBitsConfirmed = softBitsCombined(1:lags(locs(end)));
    end

    % sync word
    syncAsm = 'FCA2B63DB00D9794';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', 1, []);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    hPlot = [];
    hPeaks = [];
    if Params.plotting && ~recursive
        figure(2);
        hPlot = plot(nan, nan); hold on;
        hPeaks = plot(nan, nan, 'rx');
        hold off;
        xlabel('Samples');
        ylabel('Cross-correlation Amplitude');
        grid on;
    end
    
    i = 1;
    constellationErrorLast = 0;
    constellationErrorFirst = 0;
    lastFrame = 0;
    softBitsAll = [];
    while i < numel(symbols)
        if i+Params.blockSize-1 < numel(symbols)
            symbolsBlock = symbols(i:i+Params.blockSize-1);
        else
            lastFrame = 1;
            symbolsBlock = symbols(i:end);
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
            [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevel+0.2); % , 'MinPeakHeight', 40+signalLevel
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
                    part2 = symbolsBlock(lags(locs(end))/2+1+8192+1:end);
                    softBits = constellation(1, part2, Params);
                    constellationErrorLast = 1; 
    
                % first few frames have different constellation
                elseif lags(locs(1)) > 16384+1
                    part2 = softBits(lags(locs(1))-1:end);
                    part1 = symbolsBlock(1:lags(locs(1))/2-1);
                    softBits = constellation(1, part1, Params);
                    constellationErrorFirst = 1; 
                end
            end
            
            % last few frames have different constellation
            if constellationErrorLast
                constellationErrorLast = 0;
                softBitsCombined = [part1; softBits];
                softBitsConfirmed = findPeaksConstellationError(softBitsCombined, syncAsmBits);
                break

            % first few frames have different constellation
            elseif constellationErrorFirst
                constellationErrorFirst = 0;
                softBitsCombined = [softBits; part2];
                softBitsConfirmed = findPeaksConstellationError(softBitsCombined, syncAsmBits);
                break
            
            % recursive call for different constellations
            elseif all(~mod(widths, 1024)) && recursive
                softBitsConfirmed = softBits;
                break
            
            % last frame should contain alls softBits
            elseif all(~mod(widths, 1024)) && lastFrame
                softBitsConfirmed = softBits;
                
            % normal case
            elseif all(~mod(widths, 1024)) && ~lastFrame && ~recursive
                softBitsConfirmed = softBits(1:lags(locs(end)));
                break
            end
        end
        softBitsAll = [softBitsAll; softBitsConfirmed];
        i = i + numel(softBitsConfirmed)/2;

        % plotting
        if Params.plotting && i <= 7401293
            set(hPlot, 'XData', lags, 'YData', corrNormalized);
            set(hPeaks, 'XData', lags(locs), 'YData', pks);
            xlim([0 max(lags)]);
            title(sprintf('Cross-correlation of FCA2B63DB00D9794 and encoded Softbits using %s', mat2str(Params.constellations{j})));
            drawnow;
        end
    end
end
