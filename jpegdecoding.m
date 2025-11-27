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
    F = cell(1, numel(qualityFactors));
    for i = 1:numel(qualityFactors)
        if ~isempty(qualityFactors)
            if 20 < qualityFactors(i) && qualityFactors(i) < 50
                F{i} = 5000 / qualityFactors(i);
            elseif 50 <= qualityFactors(i) && qualityFactors(i) <= 100
                F{i} = 200 - 2 * qualityFactors(i);
            else
                F{i} = 100;
            end
        end
    end
    
    % huffman, run-size decoding
    if ~Params.thumbnailsWorkspace
        for i = 1:numel(mcus)
            if isempty(mcus{i}) 
                continue
            end
            mcu = mcus{i};
            pos = 1;
            if apids(i) == 70
                continue
            end
            
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
                            break;
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
                magnitudes{j} = [dcMagnitude, acMagnitudes];
                j = j + 1;
                pos = pos + length(key);
            end
            thumbnails{i} = magnitudes;
            % if numel(thumbnails) == 200
            %     break
            % end
        end
        save('data/thumbnails.mat', 'thumbnails');
    else
        load('data/thumbnails.mat');
    end
    
    spatials = cell(1, numel(thumbnails));
    for i = 1:numel(thumbnails)
        magnitudes = thumbnails{i};
        for j = 1:numel(magnitudes)
            if j==1
                magnitudes{j}(1) = 0 + magnitudes{j}(1);
            elseif isempty(magnitudes{j})
                break
            else
                magnitudes{j}(1) = magnitudes{j-1}(1) + magnitudes{j}(1);
            end
        end
        % thumbnails{i} = magnitudes;
    
        for j = 1:numel(magnitudes)
            magnitude = magnitudes{j};
            if isempty(magnitude)
                spatials{i}{j} = zeros(8,8);
                continue
            end
            zigzag = zeros(8,8);
        
            for k = 0:63
                [r, c] = find(DCT.zigzagTable == k);
                zigzag(r,c) = magnitude(k+1); 
            end
            zigzagQuant = zigzag .* DCT.quantizationTable * double(F{i})/100;
            spatials{i}{j} = idct2(zigzagQuant) + 128;
        end
    end
    
    channel64 = [];
    channel65 = [];
    channel68 = [];
    channel70 = [];
    jpeg64 = [];
    jpeg65 = [];
    jpeg68 = [];
    jpeg70 = [];
    % sort spatials to there respective apid
    % for i = 1:numel(apids)
    for i = 1:numel(thumbnails)
        apid = apids(i);
        for j = 1:numel(spatials{i})
            spatial = spatials{i}{j};
            if apid == 64
                channel64 = [channel64, spatial];
                if length(channel64) == 1568
                    jpeg64 = [jpeg64; channel64];
                    channel64 = [];
                end
            elseif apid == 65
                channel65 = [channel65, spatial];
                if length(channel65) == 1568
                    jpeg65 = [jpeg65; channel65];
                    channel65 = [];
                end
            elseif apid == 68
                channel68 = [channel68, spatial];
                if length(channel68) == 1568
                    jpeg68 = [jpeg68; channel68];
                    channel68 = [];
                end
            else
                channel70 = [channel70, spatial];
                if length(channel70) == 1568
                    jpeg70 = [jpeg70; channel70];
                    channel70 = [];
                end
            end
        end
    end
    
    Images.jpeg64 = uint8(jpeg64);
    Images.jpeg65 = uint8(jpeg65);
    Images.jpeg68 = uint8(jpeg68);
    % 
    % Images.rgb = cat(3, Images.jpeg68, Images.jpeg65, Images.jpeg64);
    % 
    % if Params.plotting
    %     figure;
    %     imshow(Images.jpeg64);
    %     title("Channel 64")
    %     figure;
    %     imshow(Images.jpeg65);
    %     title("Channel 65")
    %     figure;
    %     imshow(Images.jpeg68);
    %     title("Channel 68")
    %     figure;
    %     imshow(Images.rgb);
    %     title("RGB aus 68/65/64")
    % end
end