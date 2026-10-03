function Images = jpegdecoding(mcus, qualityFactors, apids, Huffman, DCT, Params, Meta)
    aligned = nargin >= 7 && ~isempty(Meta);
    if isempty(mcus)
        Images.jpeg64 = zeros(0,1568,'uint8');
        Images.jpeg65 = Images.jpeg64;
        Images.jpeg68 = Images.jpeg64;
        Images.rgb = zeros(0,1568,3,'uint8');
        Images.scanTimes = [];
        Images.valid64 = false(0,1568);
        Images.valid65 = Images.valid64;
        Images.valid68 = Images.valid64;
        return
    end

    % calculate magnitude
    function magnitude = decodeMagnitude(codeWord, bitArray)
        if codeWord == 0
            magnitude = 0;
            return
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
    
    imageHeight = 664;
    if aligned
        imageHeight = 8*numel(unique(Meta.time));
    end
    if Params.plotting
        figure;
        sub64 = subplot(3,1,1);
        h64 = imshow(repmat(uint8(128),imageHeight,1568));
        title('Channel 64');
        sub65 = subplot(3,1,2);
        h65 = imshow(repmat(uint8(128),imageHeight,1568));
        title('Channel 65');
        sub68 = subplot(3,1,3);
        h68 = imshow(repmat(uint8(128),imageHeight,1568));
        title('Channel 68');
    end
    channel64 = [];
    channel65 = [];
    channel68 = [];
    jpeg64 = [];
    jpeg65 = [];
    jpeg68 = [];
    
    if aligned
        [scanTimes,~,scanRows] = unique(Meta.time);
        jpeg64 = repmat(uint8(128),8*numel(scanTimes),1568);
        jpeg65 = jpeg64;
        jpeg68 = jpeg64;
        valid64 = false(size(jpeg64));
        valid65 = valid64;
        valid68 = valid64;
    end
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
        while pos <= numel(mcu) && j <= 14
            % DC Part
            dcFound = false;
            for k = 1:min(9,numel(mcu)-pos+1)
                % check if we have found all 14 thumbnails
                if mcu(pos+k-1:end) == ones(1, numel(mcu(pos+k-1:end))) | j > 14
                    goToNextMcu = 1;
                    break
                end
                key = sprintf('%d', mcu(pos:pos+k-1));
                if isKey(DCMap.symbols,key)
                    nextSymbolLength = double(DCMap.symbols(key));
                    if pos+k+nextSymbolLength-1 > numel(mcu)
                        break
                    end
                    if nextSymbolLength ~= 0
                        bitArray = mcu(pos+k:pos+k+nextSymbolLength-1);
                        dcMagnitude = decodeMagnitude(nextSymbolLength, bitArray);
                    else
                        nextSymbolLength = 0;
                        dcMagnitude = 0;
                    end
                    dcFound = true;
                    break
                end
            end
            if goToNextMcu
                break
            end
            if ~dcFound
                break  % unknown DC code: stop decoding this MCU packet
            end
            pos = pos + k + nextSymbolLength;
    
            % AC Part
            acMagnitudes = zeros(1,63);
            acCount = 1;
            complete = false;
            while pos <= numel(mcu) && acCount <= 63
                found = false;
                for k = 1:min(16, numel(mcu)-pos+1)
                    key = sprintf('%d', mcu(pos:pos+k-1));
                    if isKey(ACMap.symbols,key)
                        if strcmp(ACMap.symbols(key), '0/0') % EOB
                            pos = pos + k;
                            complete = true;
                            found = true;
                            break;
                        elseif strcmp(ACMap.symbols(key), '15/0') % ZRL
                            if acCount+15 > 63
                                break;
                            end
                            acCount = acCount + 16;
                            pos = pos + k;
                            found = true;
                            break;
                        end

                        runsize = str2double(split(ACMap.symbols(key), '/'));
                        if acCount+runsize(1) > 63 || pos+k+runsize(2)-1 > numel(mcu)
                            break;
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
                if ~found || complete, break; end
            end
            if ~(complete || acCount == 64), break; end

            % differential decoding of DC-values
            if j==1 || isempty(magnitudes{j-1})
                dcMagnitude = 0 + dcMagnitude;
            else
                dcMagnitude = magnitudes{j-1}(1) + dcMagnitude;
            end
    
            magnitudes{j} = [dcMagnitude, acMagnitudes];
            j = j + 1;
        end
        
        for j = 1:numel(magnitudes)
            magnitude = magnitudes{j};
    
            % zig-zag order and 2d inverse-discrete-cosine-transform
            if ~isempty(magnitude)
                zigzag = zeros(8,8);
                zigzag(zigzagIdx) = magnitude(1:64);
                fq = F(min(i, numel(F)));
                quant = max(1, floor((DCT.quantizationTable*fq + 50)/100));
                zigzagQuant = zigzag .* quant;
                spatial = idct2(zigzagQuant) + 128;
            else
                spatial = 128*ones(8,8);
            end

            spatial = uint8(spatial);
            
            if aligned
                % place each block at its timestamp and MCU position
                row = (scanRows(i)-1)*8+(1:8);
                col = Meta.mcu(i)*8+(j-1)*8+(1:8);
                if apid == 64
                    jpeg64(row,col) = spatial;
                    valid64(row,col) = ~isempty(magnitude);
                elseif apid == 65
                    jpeg65(row,col) = spatial;
                    valid65(row,col) = ~isempty(magnitude);
                elseif apid == 68
                    jpeg68(row,col) = spatial;
                    valid68(row,col) = ~isempty(magnitude);
                end
                continue
            end
            % match spatial with respective apid
            if apid == 64
                channel64 = [channel64, spatial];
                if length(channel64) == 1568
                    jpeg64 = [jpeg64; channel64];
                    channel64 = [];
                    if Params.plotting
                        set(h64, 'CData', uint8(jpeg64));
                        drawnow;
                    end
                end
            elseif apid == 65
                channel65 = [channel65, spatial];
                if length(channel65) == 1568
                    jpeg65 = [jpeg65; channel65];
                    channel65 = [];
                    if Params.plotting
                        set(h65, 'CData', uint8(jpeg65));
                        drawnow;
                    end
                end
            elseif apid == 68
                channel68 = [channel68, spatial];
                if length(channel68) == 1568
                    jpeg68 = [jpeg68; channel68];
                    channel68 = [];
                    if Params.plotting
                        set(h68, 'CData', uint8(jpeg68));
                        drawnow;
                    end
                end
            end
        end
        if aligned && Params.plotting
            if apid == 64
                set(h64, 'CData', jpeg64);
            elseif apid == 65
                set(h65, 'CData', jpeg65);
            elseif apid == 68
                set(h68, 'CData', jpeg68);
            end
            drawnow limitrate;
        end
    end
    if aligned && Params.plotting
        set(h64, 'CData', jpeg64);
        set(h65, 'CData', jpeg65);
        set(h68, 'CData', jpeg68);
        drawnow;
    end
    if Params.export && Params.plotting
        exportgraphics(gcf, "data/plots/images.pdf")
        exportgraphics(sub64, "data/plots/image_channel64.pdf")
        exportgraphics(sub65, "data/plots/image_channel65.pdf")
        exportgraphics(sub68, "data/plots/image_channel68.pdf")
    end

    IR = 255 - uint8(jpeg68);
    rgb = cat(3, uint8(jpeg64), uint8(jpeg65), IR);

    if Params.plotting
        figure;
        imshow(rgb);
        title("RGB Image");
    end
    if Params.export && Params.plotting
        exportgraphics(gcf, "data/plots/image_rgb.pdf")
    end

    Images.jpeg64 = jpeg64;
    Images.jpeg65 = jpeg65;
    Images.jpeg68 = jpeg68;
    Images.rgb = rgb;
    if aligned
        Images.scanTimes = scanTimes;
        Images.valid64 = valid64;
        Images.valid65 = valid65;
        Images.valid68 = valid68;
    end
end
