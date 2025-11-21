function softBitsConfirmed = constellation(currentIdx, symbols, Params)
    % sync word
    syncAsm = 'FCA2B63DB00D9794';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', 1, []);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    % constellation rotation and symmetry
    for i=1:length(Params.constellations)
        % qpsk demodulation soft-decoding
        softBits = pskdemod( ...
                    symbols, ...
                    Params.M, ...
                    pi/4, ...
                    Params.constellations{i}, ...
                    OutputType="llr" ...
                    );
    
        % cross-correlation
        [corr, lags] = xcorr(softBits, syncAsmBits);
        corrNormalized = abs(corr)./max(abs(corr));
        signalLevel = quantile(abs(corrNormalized), 0.999);

        if signalLevel > 0.6
            continue
        end
    
        % % find peaks and calculate widths
        [pks, locs] = findpeaks(corrNormalized, 'MinPeakDistance',16384-1, 'Threshold', 0.1, 'MinPeakHeight', signalLevel+0.15); % , 'MinPeakHeight', 40+signalLevel
        widths = diff(locs)/16;

        % check if we are in the negative case
        if corr(locs) < 0
            continue
        end

        if all(widths == 1024)
            firstPeak = locs(1);
            expectedNumPeaks = ceil(numel(corrNormalized(firstPeak:end))/16384);
            if expectedNumPeaks ~= numel(locs)
                part1 = softBits(1:lags(locs(end))+16384);
                part2 = symbols(lags(locs(end))/2+8192+1:end);
                softBits = constellation(1, part2, Params);
            end
        end

        % if currentIdx >= 90
        %     figure(1);
        %     plot(lags, corrNormalized); hold on;
        %     yline(signalLevel);
        %     plot(lags(locs), pks, 'rx');
        %     hold off;
        %     title(currentIdx);
        %     pause(0.5);
        % end

        if exist("part1", "var")
            softBits = [part1; softBits];
        end

        if all(widths == 1024)
            softBitsConfirmed = softBits;
            break
        end
    end

    % plotting
    if Params.plotting
        figure;
        plot(lags, corr); hold on;
        plot(lags(locs), pks, 'rx');
        hold off;
        xlim([firstFrameStart lastFrameStart]);
        xlabel('Samples');
        ylabel('Cross-correlation amplitude');
        title(sprintf('Cross-correlation of FCA2B63DB00D9794 and encoded Softbits using %s', mat2str(Params.constellations{i})));
        grid on;
    end
end