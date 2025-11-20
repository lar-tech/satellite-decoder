function [softBits, bestIdx, snrVals] = constellation2(symbols, Params)
    % sync word
    syncAsm = 'FCA2B63DB00D9794';
    syncAsmBytes = sscanf(syncAsm, '%2x').';
    syncAsmBits = de2bi(syncAsmBytes, 8, 'left-msb');
    syncAsmBits = reshape(syncAsmBits.', 1, []);
    syncAsmBits = 2*double(syncAsmBits)-1;  % +/-1

    nConst = numel(Params.constellations);
    snrVals = -inf(1, nConst);      % SNR-Metrik pro Constellation
    bestMetric = -inf;
    bestSoftBits = [];
    bestIdx = NaN;


    for i = 1:nConst
        % QPSK Demodulation mit aktueller Constellation
        softBits_i = pskdemod( ...
            symbols, ...
            Params.M, ...
            pi/4, ...
            Params.constellations{i}, ...
            OutputType = "llr" ...
        );

        % Kreuzkorrelation mit Sync-Wort
        [corr, lags] = xcorr(softBits_i, syncAsmBits);

        % Peaks suchen
        [pks, locs] = findpeaks(corr, ...
                                "MinPeakDistance", 16384-1, ...
                                "Threshold", 1);

        % Breite der Peaks -> ergibt deine 1024er-Bedingung
        width = diff(locs)/16;
        if all((1015 < width)) && all((width < 1035)) && ~isempty(width)
            width = 1024;
        else
            width = 0;
        end

        % SNR-/Qualitätsmetrik aus der Korrelation bestimmen
        if (1015 < width) && (width < 1035) && ~isempty(pks)
            % Einfaches Maß: Peak-Höhe / Rausch-Std der Korrelation
            % Rauschanteil: Korrelation ohne +-win um die Peaks
            win = 20;
            mask = true(size(corr));
            for k = 1:numel(locs)
                idx = max(locs(k)-win,1):min(locs(k)+win,numel(corr));
                mask(idx) = false;
            end
            noise = corr(mask);
            noiseStd = std(noise);

            if noiseStd == 0
                metric = -inf;
            else
                metric = max(pks) / noiseStd;
            end
        else
            % falls Breite nicht passt oder keine Peaks gefunden wurden
            metric = -inf;
        end

        snrVals(i) = metric;

        % Beste Constellation bisher merken
        if metric > bestMetric
            bestMetric = metric;
            bestSoftBits = softBits_i;
            bestIdx = i;
        end

        % Plot für jede Constellation (optional)
        figure(1);
        plot(lags, corr); hold on;
        plot(lags(locs), pks, 'rx');
        hold off;
        xlim([0 length(corr)/2]);
        xlabel('Samples');
        ylabel('Cross-correlation amplitude');
        title(sprintf('Cross-corr FCA2... und Softbits (Const %d: %s)', ...
              i, mat2str(Params.constellations{i})));
        grid on;
    end

    % Am Ende: Softbits der besten Constellation zurückgeben
    softBits = bestSoftBits;
end
