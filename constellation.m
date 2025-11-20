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
    
        % find peaks and calculate widths
        [pks, locs] = findpeaks(corr, 'MinPeakDistance',16384-5, 'Threshold', 70);
        widths = median(diff(locs))/16;

        
        % extract only whole frames
        % if any(widths == 1024) && ~lastFrame
        %     numberFrames = find(diff(locs)/16 == widths);
        %     lastFrameStart = lags(locs(numberFrames(end)+1));
        %     softBitsFramed = softBits(1:lastFrameStart-1);
        %     break
        % elseif any(widths == 1024) && lastFrame
        %     softBitsFramed = softBits;
        %     break
        % end
        if widths == 1024
            % plot(lags, corr); hold on;
            % plot(lags(locs), pks, 'rx');
            % hold off;
            % grid on;
            softBitsConfirmed = softBits;
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