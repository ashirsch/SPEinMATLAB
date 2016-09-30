% Copyright (c) 2010 Rashid Zia
% Loads data from WinSpec32 SPE v2.5 files
%        and from LightField SPE v3.0 files
% Written for MatLab R2015b
%
% Revised Aug. 2016 Alex Hirsch
%
% Version 14.1

function [SPE, pathname] = load_SPE_filetype(instruction, startingfolder)

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

        %% Error case for SPE 2.X file type  
        if floor(header_version)==2
            error(['This version of load_SPE_filetype is not configured for SPE ',...
                num2str(header_version,'%.1f'),'. Check source for commented legacy code.'])              

        %% For SPE 3.X with any number of RoIs and frames    
        elseif floor(header_version)==3 && nframes >= 1
            %% Parse the XML footer
            fread(file_id,footer-ftell(file_id));
            xmlFile=fopen('xmlFile.tmp','w');              
            xmlText=fread(file_id,inf,'int8=>char')';
            fwrite(xmlFile,xmlText); % Write XML to a separate temp file for MatLab processing
            fclose(xmlFile);
            xmlParse=xml2struct('xmlFile.tmp');

            % Trim xmlParse struct
            cameraSettings=xmlParse.SpeFormat.DataHistories.DataHistory.Origin.Experiment.Devices.Cameras.Camera;
            regionOfInterest=cameraSettings.ReadoutControl.RegionsOfInterest.CustomRegions.RegionOfInterest;

            %% Extract wavelength string data
            wavelength = xmlParse.SpeFormat.Calibrations.WavelengthMapping.Wavelength.Text;

            %% Determine number of ROIs 
            if ~iscell(regionOfInterest)
                ROI{n,1} = regionOfInterest;
            else
                ROI = regionOfInterest;
            end   
            nROI = size(ROI, 2);

            %% Reshape structures on first pass of n
            if n == 1;
                SPE.data = cell(SPE.nfiles,nframes,nROI);
                SPE.xcoord = cell(SPE.nfiles,1,nROI); 
                SPE.ycoord = cell(SPE.nfiles,1,nROI);
            end

            %% Assign ycoord values
            for ROI_ind = 1:nROI
                yStart = str2num(ROI{ROI_ind}.Attributes.y);  %#ok<*ST2NM>
                yBinning = str2num(ROI{ROI_ind}.Attributes.yBinning);
                yHeight = str2num(ROI{ROI_ind}.Attributes.height);
                ys = (yStart:yBinning:yStart+yHeight-1); 
                SPE.ycoord{n,1,ROI_ind} = ys; 
            end

            %% Assign xcoord values
            if ~isempty(wavelength)
                SPE.wavelength{n, 1} = str2num(wavelength);
            end
            for ROI_ind = 1:nROI
                xStart = str2num(ROI{ROI_ind}.Attributes.x);
                xBinning = str2num(ROI{ROI_ind}.Attributes.xBinning);
                xWidth = str2num(ROI{ROI_ind}.Attributes.width);
                xs = (xStart:xBinning:xStart+xWidth-1); 
                SPE.xcoord{n,1,ROI_ind} = xs; 
            end
            %% Save footer struct
            SPE.footer{n} = xmlParse.SpeFormat; 
            %% Load image/spectral data
            fclose(file_id);
            file_id=fopen([pathname,char(filename(n))]);
            fseek(file_id,4100,'bof'); 
            for m=1:nframes
                for s = 1:nROI
                    if nROI > 1; % xdim & ydim default to 0 for nRoI > 1
                        xdim = length(SPE.xcoord{n,1,s});
                        ydim = length(SPE.ycoord{n,1,s});
                    end
                    SPE.data{n,m,s}=fread(file_id,double([xdim, ydim]),datatype);
                end
            end
            %% Duplicate and extract ROI and binning info for easier accessibility
            for s = 1:nROI
                SPE.regionsOfInterest{n,1,s} = ROI{s};
            end
            
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