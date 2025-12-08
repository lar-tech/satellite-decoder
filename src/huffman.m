function [DCMap, ACMap] = huffman(Huffman)
    function dict = generateDCDict(Huffman)
        lengths = Huffman.lDc.lengths;
        symbols = Huffman.lDc.symbols;
        code = 0;            
        k = 1;                
        dict = cell(sum(lengths), 2);
        row = 1;

        for len = 1:16
            code = bitshift(code, 1);
            for n = 1:lengths(len)
                bits = dec2bin(code, len) - '0';
                dict{row, 1} = symbols(k);
                dict{row, 2} = sprintf('%d',bits);
                code = code + 1;
                k = k + 1;
                row = row + 1;
            end
        end
    end

    function acDict = generateACDict(Huffman)
        code = 0;
        idx = 1;
        acDict = {};
    
        for L = 1:16
            numCodes = Huffman.lAc.lengths(L);
            for n = 1:numCodes
                symbol = Huffman.lAc.symbols(idx);
                idx = idx + 1;
                run = bitshift(symbol, -4);
                sizeVal = bitand(symbol, 15);
                codeWord = dec2bin(code, L);   
                acDict{end+1,1} = sprintf('%d/%d', run, sizeVal); 
                acDict{end,2}   = L;                              
                acDict{end,3}   = codeWord;                       
                code = code + 1;
            end
            code = bitshift(code, 1);
        end
    end

    dcDict = generateDCDict(Huffman);
    acDict = generateACDict(Huffman);
    DCMap.lengths = containers.Map(dcDict(:,1), dcDict(:,2));
    DCMap.symbols = containers.Map(dcDict(:,2), dcDict(:,1));
    ACMap.rs = containers.Map(acDict(:,1), acDict(:,3));
    ACMap.symbols = containers.Map(acDict(:,3), acDict(:,1));
end