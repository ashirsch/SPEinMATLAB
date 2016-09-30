% Copyright (c) 2010 Rashid Zia
% Loads data from LightField SPE v2.X files
% Written for MatLab R2015b
%
% Revised June 2016 Alex Hirsch
%
% Version 14.1 - For use with older SPE versions

function [SPE, pathname] = load_SPE2_filetype(instruction, startingfolder)

if nargin == 0  
    instruction = 'Pick a SPE to load';
end

if nargin ~= 2
    startingfolder = cd;
end

%% Set up to navigate to .spe files
[filename, pathname, filterindex] = uigetfile( ...
{  '*.spe', 'WinSpec32 v2.5 / LightField v3.0 files'; ...
   '*.*',  'All Files (*.*)', ... 
   },...
   instruction, ...
   startingfolder,...
   'MultiSelect', 'on');


if filterindex ~= 0  % If user does not click cancel 
    %% Convert single filename to cell for consistency
    if(~iscell(filename)) 
        filename = mat2cell(filename, 1); 
    end
    
    %% Preallocation of fields and cells for data and metadata
    SPE.nfiles = size(filename, 2); 
    SPE.filenames = cell(SPE.nfiles, 1); 
    SPE.header = cell(SPE.nfiles, 1); 
    SPE.data = cell(SPE.nfiles, 1); 
    SPE.footer = cell(SPE.nfiles, 1); 
    SPE.xcoord = cell(SPE.nfiles, 1); 
    SPE.ycoord = cell(SPE.nfiles, 1);
    SPE.wavelength = cell(SPE.nfiles, 1); 
    
    %% Main loading loop: read information for each file    
    for n = 1:SPE.nfiles 
        
        fprintf(['\n Loading file ', num2str(n), ' of ', num2str(SPE.nfiles),'...']);
        
        %% Read binary header information
        file_id = fopen([pathname, char(filename(n))]);

        SPE.header{n} = fread(file_id, 4100, 'ubit8=>ubit8');
        header = SPE.header{n};
        
        sw_version = str2double(char(header(689:691))');
        header_version = typecast(header(1993:1996),'single'); 
        
        xdim = typecast(header(43:44), 'uint16');
        ydim = typecast(header(657:658), 'uint16');
        footer = typecast(header(679:686), 'uint64');
        nframes = typecast(header(1447:1448),'uint16');

        datatype = typecast(header(109:110), 'uint16'); 
        % Convert SPE datatype code to equivalent MATLAB string
        if datatype == 0
            datatype = 'single';
        elseif datatype == 1
            datatype = 'int32';
        elseif datatype == 2
            datatype = 'int16';
        elseif datatype == 3
            datatype = 'uint16';
        elseif datatype == 8
            datatype = 'uint32';
        end

        %% Error case for newer SPE filetypes  
        if floor(header_version) > 2
            error(['This version of load_SPE_filetype is not configured for SPE ',...
                num2str(header_version,'%.1f'),'. Try using the newer file loader.'])        
        %% For SPE 2.X with one frame only
        elseif floor(header_version)==2 && nframes == 1
            SPE.filenames = cell(1, SPE.nfiles); % Create cell for filename strings
            ROI = double(typecast(header(1513:1524), 'int16'));
            xs = linspace(ROI(1), ROI(2), (ROI(2)-ROI(1)+1)/ROI(3));
            ys = linspace(ROI(4), ROI(5), (ROI(5)-ROI(4)+1)/ROI(6));
            npairs = double(header(3103));
            polyCoef = typecast(header(3264:3264+8*npairs-1), 'double');
            SPE.xcoord{n} = polyval(flipud(polyCoef), xs);
            SPE.ycoord{n} = ys;
            SPE.data{n} = squeeze(fread(id, double([xdim, ydim]), datatype));
        %% Error case for multiple frames
        elseif nframes > 1
            error(['load_SPE_filetype is not configured for SPE ',...
                num2str(sw_version, '%.1f'), ' files containing multiple frames.'])
        %% Error case for unrecognized file
        else
            error(['load_SPE_filetype does not recognize SPE file version ', num2str(sw_version,'%.1f')])
        end 

        %% Cleanup filenames
        name = char(filename(n)); 
        SPE.filenames{n} = name(1:end-4); % Truncate .spe
        fclose(file_id);
    end 
end
end