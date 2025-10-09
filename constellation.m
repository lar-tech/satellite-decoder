function [softBits, correctConstellation] = constellation(symbols, Params)
    % sync word
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
                figure;
                plot(lags, corr); hold on;
                plot(lags(locs), pks, 'rx');
                hold off;
                xlabel('Samples');
                ylabel('Cross-correlation amplitude');
                title(sprintf('Cross-correlation of FCA2B63DB00D9794 and encoded Softbits using %s', mat2str(Params.constellations{i})));
                grid on;
            end
            break
        end
    end
end