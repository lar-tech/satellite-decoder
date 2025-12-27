function qualitycheck(Data, Params)
    if Params.plotting
        % load data
        I = single(Data.raw(:,1));
        Q = single(Data.raw(:,2));
        x = (I + 1j*Q);
        fs = Data.fs;
        
        % baseband signal
        figure;
        plot(real(x)); hold on;
        plot(imag(x)); hold off;
        ylim([-0.02, 0.02]);
        xlabel("Sample")
        ylabel("Amplitude")
        legend("Real Part", "Imaginary Part")
        grid();
        if Params.export
            exportgraphics(gcf, "data/plots/qc_baseband.pdf")
        end

        x = x(1:100000);
        % scatterplot: baseband signal 
        figure;
        plot(real(x), imag(x), '.', LineStyle='none');
        ylim([-0.02, 0.02]);
        xlabel("I-Part")
        ylabel("Q-Part")
        axis equal;
        axis([-0.015 0.015 -0.015 0.015]);
        grid();
        if Params.export
            exportgraphics(gcf, "data/plots/qc_scatter.pdf")
        end

        % power spectral density
        [pxx,f] = pwelch(x,[],[],[],fs,'centered');
        psdDb = 10 .* log10(pxx);
        figure;
        plot(f/1000, psdDb);
        xlabel("Frequency [kHz]");
        ylabel("Magnitude [dB]");
        grid();
        if Params.export
            exportgraphics(gcf, "data/plots/qc_psd.pdf")
        end

        % waterfall
        nFFT    = 1024;
        overlap = nFFT/2;
        window  = hanning(nFFT);
        [S, f, t] = spectrogram(x, window, overlap, nFFT, Data.fs, "centered", "psd");
        U   = sum(window.^2);                    
        Pxx = (abs(S).^2) / (Data.fs * U);       
        sdB = 10*log10(Pxx + eps); 
        figure;
        imagesc(f/1e3, t, sdB.');
        axis xy;
        cb = colorbar;
        cb.Label.String = 'Power [dB]';
        xlabel("Frequency [kHz]");
        ylabel("Time [s]");
        if Params.export
            exportgraphics(gcf, "data/plots/qc_waterfall.pdf")
        end
   end
end