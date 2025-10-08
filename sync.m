function [frames, correctConstellation] = sync(symbols, Params, Viterbi)
    % sync word before using viterbi
    syncAsm = 'FCA2B63DB00D9794';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', 1, []);
    syncAsmBits = 2*double(syncAsmBits)-1;
    
    %% constellation rotation and symmetry
    for i=1:length(Params.constellations)
        % qpsk demodulation hard-decoding
        softBits = pskdemod( ...
                    symbols, ...
                    Params.M, ...
                    pi/4, ...
                    Params.constellations{i}, ...
                    OutputType="llr" ...
                    ); 
    
        % cross-correlation
        [corr,lags] = xcorr(softBits, syncAsmBits);
    
        % find peaks and calculate widths
        [pks,locs] = findpeaks(corr, 'MinPeakDistance',15500, 'Threshold',40);
        width = mean(diff(locs))/16;
        if width >= 1020 || width <= 1030 && width==1024
            correctConstellation = Params.constellations{i};
            if Params.plotting == true
                figure();
                plot(lags, corr); hold on;
                plot(lags(locs), pks, 'rx');
                hold off;
                xlabel('Samples');
                ylabel('Cross-correlation amplitude');
                title(sprintf('Cross-correlation of FCA2B63DB00D9794 and %s', mat2str(Params.constellations{i})));
                grid on;
            end
            break
        end
    end

    %% cutting frames
    asmLen = length(syncAsmBits);
    frameLen = 16384;
    
    frames = cell(1, numel(locs));
    for k = 1:numel(locs)
        start_idx = lags(locs(k)) + asmLen + 1;
        stop_idx  = start_idx + frameLen - 1;
        if start_idx > 0 && stop_idx <= numel(softBits)
            frames{k} = softBits(start_idx:stop_idx);
        else
            frames{k} = [];
        end
    end
    validFrames = ~cellfun(@isempty, frames);
    frames = frames(validFrames);
end