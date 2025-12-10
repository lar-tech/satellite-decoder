function Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params)
    % calculate magnitude
    function magnitude = decodeMagnitude(codeWord, bitArray)
        if codeWord == 0
            magnitude = 0;
        end
        bitsVal = double(bi2de(bitArray, 'left-msb'));
        if bitArray(1) == 1
            magnitude = bitsVal;
        else
            magnitude = -((2^double(codeWord) - 1) - bitsVal);
        end
    end
    
    % create huffman tables
    [DCMap, ACMap] = huffman(Huffman);
    
    % quality factor
    Q = double(qualityFactors(:).');  
    F = 100 * ones(size(Q));  
    mask1 = Q > 20 & Q < 50;
    F(mask1) = 5000 ./ Q(mask1);    
    mask2 = Q >= 50 & Q <= 100;
    F(mask2) = 200 - 2 * Q(mask2);

    zigzagRow = zeros(1, 64);
    zigzagCol = zeros(1, 64);
    for k = 0:63
        [r, c] = find(DCT.zigzagTable == k);
        zigzagRow(k+1) = r;
        zigzagCol(k+1) = c;
    end
    zigzagIdx = sub2ind([8 8], zigzagRow, zigzagCol);
    
    figure;
    sub64 = subplot(3,1,1);
    h64 = imshow(uint8(ones(664,1568)));
    title('Channel 64');
    sub65 = subplot(3,1,2);
    h65 = imshow(uint8(ones(664,1568)));
    title('Channel 65');
    sub68 = subplot(3,1,3);
    h68 = imshow(uint8(ones(664,1568)));
    title('Channel 68');
    
    channel64 = [];
    channel65 = [];
    channel68 = [];
    channel70 = [];
    jpeg64 = [];
    jpeg65 = [];
    jpeg68 = [];
    jpeg70 = [];
    
    % huffman, run-size decoding
    for i = 1:numel(mcus)
        if isempty(mcus{i}) 
            continue
        end
        apid = apids(i);
        mcu = mcus{i};
        pos = 1;
        if apids(i) == 70
            continue
        end
        
        % entropy and run-length-decoding
        j = 1;
        goToNextMcu = 0;
        magnitudes = cell(1, 14);
        while pos < numel(mcu)
            % DC Part
            for k = 1:9
                % check if we have found all 14 thumbnails
                if mcu(pos+k-1:end) == ones(1, numel(mcu(pos+k-1:end))) | j > 14
                    goToNextMcu = 1;
                    break
                end
                key = sprintf('%d', mcu(pos:pos+k-1));
                if isKey(DCMap.symbols,key)
                    nextSymbolLength = double(DCMap.symbols(key));
                    if nextSymbolLength ~= 0 % EOB
                        bitArray = mcu(pos+k:pos+k+nextSymbolLength-1);
                        dcMagnitude = decodeMagnitude(nextSymbolLength, bitArray);
                        break
                    else
                        dcMagnitude = 0;
                    end
                end
            end
            if goToNextMcu
                break
            end
            pos = pos + k + nextSymbolLength;
    
            % AC Part
            acMagnitudes = zeros(1,63);
            acCount = 1;
            while pos <= numel(mcu)
                found = false;
                for k = 1:min(16, numel(mcu)-pos+1)
                    key = sprintf('%d', mcu(pos:pos+k-1));
                    if isKey(ACMap.symbols,key)
                        if strcmp(ACMap.symbols(key), '0/0') % EOB
                            break; 
                        elseif strcmp(ACMap.symbols(key), '15/0') % ZRL 
                            acCount = acCount + 16;
                            pos = pos + 11;
                            found = true;
                            break;
                        end
    
                        runsize = str2double(split(ACMap.symbols(key), '/'));
                        if pos+k+runsize(2)-1 > numel(mcu)
                            break;  % end
                        end
                        acCount = acCount + runsize(1);
                        nextSymbolLength = runsize(2);
                        bitArray = mcu(pos+k:pos+k+nextSymbolLength-1);
                        acMagnitudes(acCount) = decodeMagnitude(nextSymbolLength, bitArray);
                        acCount = acCount + 1;
                        pos = pos + k + nextSymbolLength;
                        found = true;
                        break;
                    end
                end
                if ~found, break; end
                if ACMap.symbols(key) == 240, continue; end
            end
    
            % differential decoding of DC-values
            if j==1
                dcMagnitude = 0 + dcMagnitude;
            else
                dcMagnitude = magnitudes{j-1}(1) + dcMagnitude;
            end
    
            magnitudes{j} = [dcMagnitude, acMagnitudes];
            j = j + 1;
            pos = pos + length(key);
        end
        
        for j = 1:numel(magnitudes)
            magnitude = magnitudes{j};
    
            % zig-zag order and 2d inverse-discrete-cosine-transform
            if ~isempty(magnitude)
                zigzag = zeros(8,8);
                zigzag(zigzagIdx) = magnitude(1:64);
                fq = F(min(i, numel(F)));
                zigzagQuant = zigzag .* DCT.quantizationTable * (fq / 100);
                spatial = idct2(zigzagQuant) + 128;
            else
                spatial = zeros(8,8);
            end

            spatial = uint8(spatial);
            
            % match spatial with respective apid
            if apid == 64
                channel64 = [channel64, spatial];
                if length(channel64) == 1568
                    jpeg64 = [jpeg64; channel64];
                    channel64 = [];
                    set(h64, 'CData', uint8(jpeg64));
                    drawnow;
                end
            elseif apid == 65
                channel65 = [channel65, spatial];
                if length(channel65) == 1568
                    jpeg65 = [jpeg65; channel65];
                    channel65 = [];
                    set(h65, 'CData', uint8(jpeg65));
                    drawnow;
                end
            elseif apid == 68
                channel68 = [channel68, spatial];
                if length(channel68) == 1568
                    jpeg68 = [jpeg68; channel68];
                    channel68 = [];
                    set(h68, 'CData', uint8(jpeg68));
                    drawnow;
                end
            end
        end  
    end
    if Params.export
        exportgraphics(gcf, "data/plots/images.pdf")
        exportgraphics(sub64, "data/plots/image_channel64.pdf")
        exportgraphics(sub65, "data/plots/image_channel65.pdf")
        exportgraphics(sub68, "data/plots/image_channel68.pdf")
    end

    IR = 255 - uint8(jpeg68);
    rgb = cat(3, uint8(jpeg64), uint8(jpeg65), IR);

    figure;
    imshow(rgb);
    title("RGB Image");
    if Params.export
        exportgraphics(gcf, "data/plots/image_rgb.pdf")
    end

    Images.jpeg64 = jpeg64;
    Images.jpeg65 = jpeg65;
    Images.jpeg68 = jpeg68;
    Images.rgb = rgb;
end