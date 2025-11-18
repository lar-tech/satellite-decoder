function softBitsFramed = constellation(lastFrame, symbols, Params)
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
    
        % find peaks and calculate widths
        [pks, locs] = findpeaks(corr, 'MinPeakDistance',16384-1, 'Threshold', 50);
        widths = int32(median(diff(locs))/16);
        
        % extract only whole frames
        if widths == 1024 && ~lastFrame
            numberFrames = find(diff(locs)/16 ~= 16384);
            if lags(locs(numberFrames(end))) ~= 0
                lastFrameStart = lags(locs(numberFrames(end)));
            else
                lastFrameStart = lags(locs(2));
            end
            softBitsFramed = softBits(1:lastFrameStart-1);
            break
        elseif widths == 1024 && lastFrame
            softBitsFramed = softBits;
            break
        end
    end


    % % plotting
    % if Params.plotting
    %     figure;
        % plot(lags, corr); hold on;
        % plot(lags(locs), pks, 'rx');
    %     hold off;
    %     xlim([firstFrameStart lastFrameStart]);
    %     xlabel('Samples');
    %     ylabel('Cross-correlation amplitude');
    %     title(sprintf('Cross-correlation of FCA2B63DB00D9794 and encoded Softbits using %s', mat2str(Params.constellations{i})));
    %     grid on;
    % end
end