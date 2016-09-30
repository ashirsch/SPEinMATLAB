# SPEinMATLAB
## v14.1
loadSPEmat is a set of functions that load Princeton Instruments SPE 3.0 and 2.X files into a MATLAB environment.

### Basic Usage
##### Loading and accessing data
Simply run load_SPE_filetype.m to load one or more SPE (3.0) files at a time:
```matlab
SPEstruct = load_SPE_filetype
```
A file selection window will open to allow browsing for source files. The result `SPEstruct` is an individual MATLAB structure object containing all of the loaded information for the files selected. Information in this object can be accessed by file, frame, and region of interest. For example, to store the raw data from the 2nd file, 3rd frame, and 2nd region of interest:
```matlab
rawdata = SPEstruct.data{2, 3, 2}
```
Use load_SPE2_filetype for older SPE filetypes (< 3.0). Some functionality may not be present in the older version.
### Dependencies
  - xml2struct.m - XML parsing of the file footer ([Mathworks FileExchange Link](https://www.mathworks.com/matlabcentral/fileexchange/28518-xml2struct))

### Version
14.1

### License
MIT
