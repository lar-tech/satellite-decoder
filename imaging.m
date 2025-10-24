function jpegImage = imaging(mcusSorted, Huffman, DCT)
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

    [DCMap, ACMap] = huffman(Huffman);
    
    % huffman, run-size decoding
    magnitudes = cell(1, 4);
    for i = 1:4
        for j = 1:numel(mcusSorted{i})
            magnitudes{i}{j} = zeros(1, 64);
        end
    end
    
    for i = 1:numel(mcusSorted)
        for j = 1:numel(mcusSorted{i})
            mcu = mcusSorted{i}{j};
            pos = 1;
    
            % DC Part
            for k = 1:9
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
                        
                        if pos+k+double(ACMap.symbols(key))-1 > numel(mcu)
                            break;  % end
                        end
                        runsize = str2double(split(ACMap.symbols(key), '/'));
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
            magnitudes{i}{j} = [dcMagnitude, acMagnitudes];
        end
    end
    
    % zig-zag, dct decoding
    for j = 1:numel(mcusSorted{1})
        magnitude = magnitudes{1}{j};
        zigzag = zeros(8,8);
        for idx = 0:63
            [r, c] = find(DCT.zigzagTable == idx);
            zigzag(r,c) = magnitude(idx+1);
        end
        zigzagQuant = zigzag .* DCT.quantizationTable;
        spatial{j} = idct2(zigzagQuant) + 128;
    end
    
    % combine image
    blockSize = 8;
    blocksPerRow = 14;
    numBlocks = numel(spatial);
    numRows = ceil(numBlocks / blocksPerRow);
    combined = zeros(numRows * size(spatial{1}, 1), blocksPerRow * blockSize);


    idx = 1;
    for row = 1:numRows
        for col = 1:blocksPerRow
            if idx > numBlocks
                break;
            end

            y_start = (row-1)*blockSize + 1;
            y_end   = row*blockSize;
            x_start = (col-1)*blockSize + 1;
            x_end   = col*blockSize;

            combined(y_start:y_end, x_start:x_end) = spatial{idx};
            idx = idx + 1;
        end
    end

    jpegImage = uint8(combined);
end